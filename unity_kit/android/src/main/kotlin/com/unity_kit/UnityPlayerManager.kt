package com.unity_kit

import android.app.Activity
import android.content.Context
import android.os.SystemClock
import android.util.Log
import android.view.View
import android.view.ViewGroup

/// Singleton manager for the Unity player instance.
///
/// Uses reflection to instantiate Unity player classes, supporting both
/// Unity 6+ (UnityPlayerForActivityOrService) and legacy (UnityPlayer).
/// The player survives navigation to avoid costly re-initialization (Issue #1 fix).
/// Explicit resource tracking ensures proper cleanup (Issue #5 fix).
object UnityPlayerManager {
    private const val TAG = "UnityPlayerManager"

    private const val UNITY_6_CLASS = "com.unity3d.player.UnityPlayerForActivityOrService"
    private const val UNITY_LEGACY_CLASS = "com.unity3d.player.UnityPlayer"
    private const val UNITY_SEND_MESSAGE_METHOD = "UnitySendMessage"

    /// Minimum interval between pause+resume cycles to prevent rapid-fire
    /// invocations that cause Unity to hang. Multiple sources (onResume,
    /// onWindowVisibilityChanged, focus) can trigger refresh within milliseconds.
    private const val REFRESH_DEBOUNCE_MS = 150L

    @Volatile
    private var player: Any? = null

    @Volatile
    private var isLoaded = false

    @Volatile
    private var isPaused = false

    @Volatile
    private var isCreating = false

    private var activityRef: Activity? = null

    private val listeners = java.util.concurrent.CopyOnWriteArrayList<UnityEventListener>()

    @Volatile
    private var cachedSendMethod: java.lang.reflect.Method? = null

    @Volatile
    private var lastRefreshTime = 0L

    /// Whether the Unity player has been created and is available.
    val isReady: Boolean
        get() = player != null

    /// Whether the Unity player is currently loaded.
    val playerIsLoaded: Boolean
        get() = isLoaded

    /// Whether the Unity player is currently paused.
    val playerIsPaused: Boolean
        get() = isPaused

    /// Creates the Unity player using reflection.
    ///
    /// Tries Unity 6 [UnityPlayerForActivityOrService] first, then falls back
    /// to legacy [UnityPlayer]. Creation is idempotent - calling multiple times
    /// with a created player is a no-op.
    @Synchronized
    fun createPlayer(activity: Activity) {
        if (player != null) {
            Log.d(TAG, "Unity player already exists, refreshing view state")
            // Reuse existing player - refresh rendering state
            if (player is android.view.View) {
                val view = player as android.view.View
                view.bringToFront()
                view.requestLayout()
                view.invalidate()
            }
            isLoaded = true
            return
        }

        if (isCreating) {
            Log.d(TAG, "Unity player creation already in progress")
            return
        }

        isCreating = true
        activityRef = activity

        try {
            // Try Unity 6 first (UnityPlayerForActivityOrService), then legacy.
            // For Unity 6000+, use getFrameLayout() to get the embeddable View.
            player = tryCreateUnity6Player(activity) ?: tryCreateLegacyPlayer(activity)

            if (player == null) {
                Log.e(TAG, "Failed to create Unity player: no Unity classes found on classpath")
                return
            }

            isLoaded = true
            isPaused = false
            cachedSendMethod = null
            Log.i(TAG, "Unity player created: ${player!!.javaClass.simpleName}")
            focus()
            notifyCreated()
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to create Unity player", e)
            player = null
        } finally {
            isCreating = false
        }
    }

    /// Attempts to create a Unity 6+ player via reflection.
    ///
    /// Tries multiple constructor signatures for Unity 6 compatibility:
    /// 1. Context + IUnityPlayerLifecycleEvents
    /// 2. Context only
    /// 3. Activity
    private fun tryCreateUnity6Player(activity: Activity): Any? {
        return try {
            val clazz = Class.forName(UNITY_6_CLASS)
            // Try Context + IUnityPlayerLifecycleEvents
            try {
                val lifecycleClass = Class.forName("com.unity3d.player.IUnityPlayerLifecycleEvents")
                val constructor = clazz.getConstructor(Context::class.java, lifecycleClass)
                val instance = constructor.newInstance(activity, null)
                Log.d(TAG, "Created Unity 6 player (Context + IUnityPlayerLifecycleEvents)")
                instance
            } catch (_: Throwable) {
                // Try Context only
                try {
                    val constructor = clazz.getConstructor(Context::class.java)
                    val instance = constructor.newInstance(activity)
                    Log.d(TAG, "Created Unity 6 player (Context)")
                    instance
                } catch (_: Throwable) {
                    // Try Activity
                    val constructor = clazz.getConstructor(Activity::class.java)
                    val instance = constructor.newInstance(activity)
                    Log.d(TAG, "Created Unity 6 player (Activity)")
                    instance
                }
            }
        } catch (e: ClassNotFoundException) {
            Log.d(TAG, "Unity 6 class not found, trying legacy player")
            null
        } catch (e: Throwable) {
            Log.w(TAG, "Failed to create Unity 6 player", e)
            null
        }
    }

    /// Attempts to create a legacy UnityPlayer via reflection.
    ///
    /// UnityPlayer extends FrameLayout and IS a View - ideal for PlatformView embedding.
    /// Tries multiple constructor signatures:
    /// 1. Activity + IUnityPlayerLifecycleEvents (Unity 2022.3+)
    /// 2. Activity only (older Unity versions)
    private fun tryCreateLegacyPlayer(activity: Activity): Any? {
        return try {
            val clazz = Class.forName(UNITY_LEGACY_CLASS)

            // Try Activity + IUnityPlayerLifecycleEvents first (Unity 2022.3+)
            try {
                val lifecycleClass = Class.forName("com.unity3d.player.IUnityPlayerLifecycleEvents")
                val constructor = clazz.getConstructor(Activity::class.java, lifecycleClass)
                val instance = constructor.newInstance(activity, null)
                Log.d(TAG, "Created legacy Unity player (Activity + IUnityPlayerLifecycleEvents)")
                instance
            } catch (_: Throwable) {
                // Fallback: Activity only
                val constructor = clazz.getConstructor(Activity::class.java)
                val instance = constructor.newInstance(activity)
                Log.d(TAG, "Created legacy Unity player (Activity)")
                instance
            }
        } catch (e: ClassNotFoundException) {
            Log.d(TAG, "Legacy UnityPlayer class not found, trying Unity 6 player")
            null
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to create legacy Unity player", e)
            null
        }
    }

    /// Sends a message to a Unity GameObject method.
    ///
    /// Uses [UnitySendMessage] static method via reflection on the Unity player class.
    /// Caches the reflected method reference for performance.
    @Synchronized
    fun sendMessage(gameObject: String, methodName: String, message: String) {
        val currentPlayer = player
        if (currentPlayer == null) {
            Log.w(TAG, "Cannot send message: Unity player not created")
            return
        }

        try {
            val sendMethod = cachedSendMethod ?: run {
                val method = currentPlayer.javaClass.getMethod(
                    UNITY_SEND_MESSAGE_METHOD,
                    String::class.java,
                    String::class.java,
                    String::class.java,
                )
                cachedSendMethod = method
                method
            }
            sendMethod.invoke(null, gameObject, methodName, message)
        } catch (e: NoSuchMethodException) {
            cachedSendMethod = null
            // Fallback: try static method on the class directly
            try {
                val method = currentPlayer.javaClass.getDeclaredMethod(
                    UNITY_SEND_MESSAGE_METHOD,
                    String::class.java,
                    String::class.java,
                    String::class.java,
                )
                method.isAccessible = true
                method.invoke(null, gameObject, methodName, message)
                cachedSendMethod = method
            } catch (fallbackError: Exception) {
                Log.e(TAG, "Failed to send message to Unity", fallbackError)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send message to Unity", e)
        }
    }

    /// Returns the Unity player's embeddable view.
    ///
    /// For Unity 6000+ (UnityPlayerForActivityOrService): uses getFrameLayout()
    /// since the player itself no longer extends FrameLayout.
    /// For legacy UnityPlayer: the player IS a FrameLayout, returned directly.
    /// The view is detached from any existing parent before returning.
    @Synchronized
    fun getView(): View? {
        val currentPlayer = player ?: return null

        // Unity 6000+: use getFrameLayout() to get the embeddable View
        try {
            val frameLayout = currentPlayer.javaClass.getMethod("getFrameLayout").invoke(currentPlayer) as? View
            if (frameLayout != null) {
                detachFromParent(frameLayout)
                Log.d(TAG, "Got view via getFrameLayout()")
                return frameLayout
            }
        } catch (_: Exception) {
            // getFrameLayout() not available, try legacy approach
        }

        // Legacy UnityPlayer extends FrameLayout - IS a View
        if (currentPlayer is View) {
            detachFromParent(currentPlayer)
            Log.d(TAG, "Got view directly (legacy UnityPlayer)")
            return currentPlayer
        }

        Log.w(TAG, "Unity player view not found")
        return null
    }

    private fun detachFromParent(view: View) {
        val parent = view.parent
        if (parent is ViewGroup) {
            parent.removeView(view)
        }
    }

    /// Requests focus and notifies Unity of window focus change.
    /// Uses windowFocusChanged + debounced pause+resume pattern from flutter_embed_unity.
    @Synchronized
    fun focus() {
        val currentPlayer = player ?: return
        try {
            // Get the FrameLayout for focus (Unity 6000+ pattern)
            val focusView: View? = try {
                currentPlayer.javaClass.getMethod("getFrameLayout").invoke(currentPlayer) as? View
            } catch (_: Exception) {
                if (currentPlayer is View) currentPlayer else null
            }

            // windowFocusChanged on the player, requestFocus on the FrameLayout
            if (focusView != null) {
                val hasFocus = focusView.requestFocus()
                try {
                    currentPlayer.javaClass
                        .getMethod("windowFocusChanged", Boolean::class.javaPrimitiveType)
                        .invoke(currentPlayer, hasFocus)
                } catch (_: Exception) {
                    Log.d(TAG, "windowFocusChanged not available on player, skipping")
                }
            }

            // Debounced pause+resume unfreezes Unity rendering after view changes
            debouncedPauseResume(currentPlayer)

            Log.d(TAG, "Unity player focused")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to focus Unity player", e)
        }
    }

    /// Forces a pause+resume cycle on the Unity player to refresh rendering.
    ///
    /// Unlike [pause] + [resume], this method bypasses the [isPaused] guard,
    /// ensuring the cycle always executes. Needed when Unity UI freezes without
    /// the internal state reflecting it (e.g., after Activity resume, permission
    /// dialogs, or rapid visibility transitions). Pattern from flutter_embed_unity.
    ///
    /// Debounced to prevent rapid-fire invocations from multiple sources
    /// (onResume, onWindowVisibilityChanged, focus) that cause Unity to hang.
    @Synchronized
    fun refreshRendering() {
        val currentPlayer = player ?: return
        try {
            debouncedPauseResume(currentPlayer)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to refresh Unity rendering", e)
        }
    }

    /// Executes a pause+resume cycle with debounce protection.
    ///
    /// Skips the cycle if called within [REFRESH_DEBOUNCE_MS] of the last
    /// successful cycle. This prevents Unity from hanging due to rapid-fire
    /// pause/resume from multiple event sources firing near-simultaneously
    /// (e.g., Activity onResume + onWindowVisibilityChanged + focus).
    private fun debouncedPauseResume(currentPlayer: Any) {
        val now = SystemClock.elapsedRealtime()
        if (now - lastRefreshTime < REFRESH_DEBOUNCE_MS) {
            Log.d(TAG, "Pause/resume debounced (${now - lastRefreshTime}ms since last)")
            return
        }

        currentPlayer.javaClass.getMethod("pause").invoke(currentPlayer)
        currentPlayer.javaClass.getMethod("resume").invoke(currentPlayer)
        isPaused = false
        lastRefreshTime = now
        Log.d(TAG, "Unity rendering refreshed (debounced pause/resume)")
    }

    /// Sends Application.targetFrameRate to Unity via UnitySendMessage.
    ///
    /// Requires a C# receiver (e.g., FlutterBridge.SetTargetFrameRate).
    /// Falls back silently if the receiver doesn't exist on the Unity side.
    fun setTargetFrameRate(frameRate: Int) {
        if (player == null) {
            Log.d(TAG, "Cannot set target frame rate: Unity player not created")
            return
        }
        sendMessage("FlutterBridge", "SetTargetFrameRate", frameRate.toString())
        Log.d(TAG, "Set target frame rate: $frameRate")
    }

    /// Pauses the Unity player.
    @Synchronized
    fun pause() {
        val currentPlayer = player ?: return
        if (isPaused) return

        try {
            val method = currentPlayer.javaClass.getMethod("pause")
            method.invoke(currentPlayer)
            isPaused = true
            Log.d(TAG, "Unity player paused")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to pause Unity player", e)
        }
    }

    /// Resumes the Unity player.
    @Synchronized
    fun resume() {
        val currentPlayer = player ?: return
        if (!isPaused) return

        try {
            val method = currentPlayer.javaClass.getMethod("resume")
            method.invoke(currentPlayer)
            isPaused = false
            Log.d(TAG, "Unity player resumed")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to resume Unity player", e)
        }
    }

    /// Unloads the Unity player while keeping the process alive.
    @Synchronized
    fun unload() {
        val currentPlayer = player ?: return

        try {
            val method = currentPlayer.javaClass.getMethod("unload")
            method.invoke(currentPlayer)
            isLoaded = false
            isPaused = false
            Log.i(TAG, "Unity player unloaded")
            notifyUnloaded()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to unload Unity player", e)
        }
    }

    /// Quits the Unity player completely.
    ///
    /// After calling this method, a new player must be created via [createPlayer].
    @Synchronized
    fun quit() {
        val currentPlayer = player ?: return

        try {
            val method = currentPlayer.javaClass.getMethod("quit")
            method.invoke(currentPlayer)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to call quit on Unity player", e)
        } finally {
            cleanup()
            Log.i(TAG, "Unity player quit")
        }
    }

    /// Releases all resources held by the player manager.
    ///
    /// Removes the player view from its parent, clears listener references,
    /// and resets all state flags. Issue #5 fix: explicit resource tracking.
    @Synchronized
    fun dispose() {
        val currentPlayer = player

        if (currentPlayer is View) {
            detachFromParent(currentPlayer)
        }

        try {
            if (currentPlayer != null) {
                val method = currentPlayer.javaClass.getMethod("destroy")
                method.invoke(currentPlayer)
            }
        } catch (e: NoSuchMethodException) {
            // destroy() may not exist on all Unity versions
            Log.d(TAG, "Unity player has no destroy() method")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to destroy Unity player", e)
        }

        cleanup()
        Log.i(TAG, "Unity player disposed")
    }

    /// Registers a listener for Unity events.
    fun addListener(listener: UnityEventListener) {
        if (!listeners.contains(listener)) {
            listeners.add(listener)
        }
    }

    /// Removes a previously registered event listener.
    fun removeListener(listener: UnityEventListener) {
        listeners.remove(listener)
    }

    /// Clears all listeners without destroying the player.
    /// Used during hot restart to prevent stale listener references.
    fun resetListeners() {
        listeners.clear()
        Log.d(TAG, "All listeners cleared (hot restart reset)")
    }

    /// Resets internal state without destroying the player.
    private fun cleanup() {
        player = null
        isLoaded = false
        isPaused = false
        isCreating = false
        activityRef = null
        cachedSendMethod = null
        lastRefreshTime = 0L
        listeners.clear()
    }

    private fun notifyCreated() {
        for (listener in listeners) {
            try {
                listener.onCreated()
            } catch (e: Exception) {
                Log.e(TAG, "Error in onCreated listener", e)
            }
        }
    }

    private fun notifyUnloaded() {
        for (listener in listeners) {
            try {
                listener.onUnloaded()
            } catch (e: Exception) {
                Log.e(TAG, "Error in onUnloaded listener", e)
            }
        }
    }

    /// Called from Unity C# via SendMessageToFlutter.
    /// Forwards the message to all registered listeners.
    fun onUnityMessage(message: String) {
        for (listener in listeners) {
            try {
                listener.onMessage(message)
            } catch (e: Exception) {
                Log.e(TAG, "Error in onMessage listener", e)
            }
        }
    }

    /// Called when a Unity scene finishes loading.
    /// Forwards the event to all registered listeners.
    fun onSceneLoaded(name: String, buildIndex: Int, isLoaded: Boolean, isValid: Boolean) {
        for (listener in listeners) {
            try {
                listener.onSceneLoaded(name, buildIndex, isLoaded, isValid)
            } catch (e: Exception) {
                Log.e(TAG, "Error in onSceneLoaded listener", e)
            }
        }
    }
}
