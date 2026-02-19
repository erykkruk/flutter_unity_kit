import 'package:flutter/widgets.dart';

import '../bridge/bridge.dart';

/// Mixin that automatically pauses/resumes Unity when the app
/// goes to background/foreground.
///
/// Apply both [WidgetsBindingObserver] and [UnityLifecycleMixin] to your
/// [State] class so that app lifecycle events are forwarded to the bridge.
///
/// Usage:
/// ```dart
/// class _MyWidgetState extends State<MyWidget>
///     with WidgetsBindingObserver, UnityLifecycleMixin {
///   late final UnityBridge _bridge;
///
///   @override
///   UnityBridge get bridge => _bridge;
///
///   @override
///   void initState() {
///     super.initState();
///     _bridge = UnityBridgeImpl(platform: UnityKitPlatform.instance);
///     initLifecycle(); // Must call to register observer
///   }
///
///   @override
///   void dispose() {
///     disposeLifecycle(); // Must call to unregister observer
///     super.dispose();
///   }
/// }
/// ```
mixin UnityLifecycleMixin<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  /// Override this to provide the bridge instance.
  UnityBridge get bridge;

  /// Call in initState() to register the lifecycle observer.
  void initLifecycle() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Call in dispose() to unregister the lifecycle observer.
  void disposeLifecycle() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      bridge.pause();
    } else if (state == AppLifecycleState.resumed) {
      bridge.resume();
    }
  }
}
