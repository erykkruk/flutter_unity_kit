package com.unity_kit

import android.util.Log
import androidx.lifecycle.Lifecycle
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.lifecycle.FlutterLifecycleAdapter

/// Main Flutter plugin entry point for unity_kit on Android.
///
/// Registers the PlatformView factory and manages Activity/Lifecycle awareness.
/// The plugin class name must match `pluginClass` in pubspec.yaml.
class UnityKitPlugin : FlutterPlugin, ActivityAware {

    companion object {
        private const val TAG = "UnityKitPlugin"
        private const val VIEW_TYPE = "com.unity_kit/unity_view"
    }

    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var lifecycle: Lifecycle? = null

    // --- FlutterPlugin ---

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "onAttachedToEngine")
        flutterPluginBinding = binding

        binding.platformViewRegistry.registerViewFactory(
            VIEW_TYPE,
            UnityKitViewFactory(
                messenger = binding.binaryMessenger,
                activityProvider = { activityBinding?.activity },
                lifecycleProvider = { lifecycle },
            ),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "onDetachedFromEngine")
        flutterPluginBinding = null
        FlutterBridgeRegistry.clear()
        UnityPlayerManager.resetListeners()
    }

    // --- ActivityAware ---

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.d(TAG, "onAttachedToActivity")
        activityBinding = binding
        lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.d(TAG, "onDetachedFromActivityForConfigChanges")
        activityBinding = null
        lifecycle = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        Log.d(TAG, "onReattachedToActivityForConfigChanges")
        activityBinding = binding
        lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(binding)
    }

    override fun onDetachedFromActivity() {
        Log.d(TAG, "onDetachedFromActivity")
        activityBinding = null
        lifecycle = null
    }
}
