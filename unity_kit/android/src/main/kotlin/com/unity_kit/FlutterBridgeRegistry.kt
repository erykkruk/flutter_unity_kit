package com.unity_kit

import android.util.Log

/// Registry for active [UnityKitViewController] instances.
///
/// Provides static methods callable from Unity C# code (via JNI/reflection)
/// to forward messages and events from Unity to the correct Flutter view controller.
///
/// Messages are forwarded through [UnityPlayerManager] which notifies all registered
/// listeners, avoiding double event delivery (AND-M2 fix).
object FlutterBridgeRegistry {
    private const val TAG = "FlutterBridgeRegistry"

    /// Maximum message size in bytes accepted from Unity (parity with iOS: 1 MB).
    private const val MAX_MESSAGE_SIZE = 1_048_576

    private val controllers = java.util.concurrent.ConcurrentHashMap<Int, UnityKitViewController>()

    /// Registers a view controller for a given view ID.
    @JvmStatic
    fun register(viewId: Int, controller: UnityKitViewController) {
        controllers[viewId] = controller
        Log.d(TAG, "Registered controller for viewId=$viewId (total: ${controllers.size})")
    }

    /// Unregisters a view controller for a given view ID.
    @JvmStatic
    fun unregister(viewId: Int) {
        controllers.remove(viewId)
        Log.d(TAG, "Unregistered controller for viewId=$viewId (total: ${controllers.size})")
    }

    /// Forwards a Unity message through [UnityPlayerManager] to all registered listeners.
    ///
    /// Called from Unity C# via [UnityMessageManager.SendMessageToFlutter].
    @JvmStatic
    fun sendMessageToFlutter(message: String) {
        if (message.length > MAX_MESSAGE_SIZE) {
            Log.e(TAG, "Message exceeds max size ($MAX_MESSAGE_SIZE bytes), dropping")
            return
        }
        UnityPlayerManager.onUnityMessage(message)
    }

    /// Forwards a scene loaded event through [UnityPlayerManager] to all registered listeners.
    ///
    /// Called from Unity C# when a scene finishes loading.
    @JvmStatic
    fun sendSceneLoadedToFlutter(
        name: String,
        buildIndex: Int,
        isLoaded: Boolean,
        isValid: Boolean,
    ) {
        UnityPlayerManager.onSceneLoaded(name, buildIndex, isLoaded, isValid)
    }

    /// Returns the number of currently registered controllers.
    @JvmStatic
    fun controllerCount(): Int = controllers.size

    /// Clears all registered controllers. Used during plugin teardown.
    @JvmStatic
    fun clear() {
        controllers.clear()
        Log.d(TAG, "All controllers cleared")
    }
}
