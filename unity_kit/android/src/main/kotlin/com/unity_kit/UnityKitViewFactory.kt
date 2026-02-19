package com.unity_kit

import android.app.Activity
import android.content.Context
import android.util.Log
import androidx.lifecycle.Lifecycle
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/// Factory for creating [UnityKitViewController] instances.
///
/// Registered with the Flutter engine as the PlatformView factory for the
/// view type `com.unity_kit/unity_view`. Parses creation parameters from
/// the Dart side and passes them to the view controller.
class UnityKitViewFactory(
    private val messenger: BinaryMessenger,
    private val activityProvider: () -> Activity?,
    private val lifecycleProvider: () -> Lifecycle?,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    companion object {
        private const val TAG = "UnityKitViewFactory"
    }

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = parseCreationParams(args)

        Log.d(TAG, "Creating UnityKitViewController for viewId=$viewId with params=$creationParams")

        val controller = UnityKitViewController(
            context = context,
            viewId = viewId,
            messenger = messenger,
            config = creationParams,
            activityProvider = activityProvider,
        )

        // Register lifecycle observer if lifecycle is available
        val lifecycle = lifecycleProvider()
        if (lifecycle != null) {
            try {
                controller.lifecycle = lifecycle
                lifecycle.addObserver(controller)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to register lifecycle observer", e)
            }
        }

        return controller
    }

    /// Parses the creation parameters sent from the Dart side.
    ///
    /// Expected keys:
    /// - `fullscreen` (Boolean)
    /// - `hideStatusBar` (Boolean)
    /// - `runImmediately` (Boolean)
    /// - `platformViewMode` (String)
    private fun parseCreationParams(args: Any?): Map<String, Any?> {
        if (args == null) return emptyMap()

        return when (args) {
            is Map<*, *> -> {
                val result = mutableMapOf<String, Any?>()
                args.forEach { (key, value) ->
                    if (key is String) {
                        result[key] = value
                    }
                }
                result
            }
            else -> {
                Log.w(TAG, "Unexpected creation params type: ${args.javaClass.simpleName}")
                emptyMap()
            }
        }
    }
}
