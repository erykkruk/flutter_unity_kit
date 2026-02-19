/// Flutter plugin for Unity 3D integration.
///
/// Provides typed bridge communication, lifecycle management,
/// and a communication layer for Flutter + Unity apps.
///
/// Example:
/// ```dart
/// import 'package:unity_kit/unity_kit.dart';
///
/// // Create bridge (independent of widget)
/// final bridge = UnityBridgeImpl(platform: UnityKitPlatform.instance);
/// await bridge.initialize();
///
/// // Use in widget
/// UnityView(
///   bridge: bridge,
///   config: const UnityConfig(sceneName: 'MainScene'),
///   onReady: (bridge) => bridge.send(UnityMessage.command('Init')),
/// )
/// ```
library unity_kit;

export 'src/bridge/bridge.dart';
export 'src/exceptions/exceptions.dart';
export 'src/models/models.dart';
export 'src/platform/platform.dart';
export 'src/streaming/streaming.dart';
export 'src/widgets/widgets.dart';
