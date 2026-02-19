import 'platform_view_mode.dart';

/// Configuration for Unity widget initialization.
///
/// Example:
/// ```dart
/// const config = UnityConfig(
///   sceneName: 'GameScene',
///   fullscreen: false,
///   targetFrameRate: 60,
/// );
/// ```
class UnityConfig {
  /// Creates a new [UnityConfig].
  const UnityConfig({
    this.sceneName = 'MainScene',
    this.fullscreen = false,
    this.unloadOnDispose = true,
    this.hideStatusBar = false,
    this.runImmediately = true,
    this.targetFrameRate = 60,
    this.platformViewMode = PlatformViewMode.hybridComposition,
  });

  /// Creates config for fullscreen Unity rendering.
  factory UnityConfig.fullscreen({String sceneName = 'MainScene'}) {
    return UnityConfig(
      sceneName: sceneName,
      fullscreen: true,
      hideStatusBar: true,
    );
  }

  /// Name of the Unity scene to load on initialization.
  final String sceneName;

  /// Whether Unity should render in fullscreen mode.
  final bool fullscreen;

  /// Whether to unload Unity when the widget is disposed.
  final bool unloadOnDispose;

  /// Whether to hide the system status bar.
  final bool hideStatusBar;

  /// Whether to start Unity player immediately on creation.
  final bool runImmediately;

  /// Target frame rate for Unity rendering.
  final int targetFrameRate;

  /// Platform view rendering mode (Android only).
  final PlatformViewMode platformViewMode;

  /// Creates a copy with the given fields replaced.
  UnityConfig copyWith({
    String? sceneName,
    bool? fullscreen,
    bool? unloadOnDispose,
    bool? hideStatusBar,
    bool? runImmediately,
    int? targetFrameRate,
    PlatformViewMode? platformViewMode,
  }) {
    return UnityConfig(
      sceneName: sceneName ?? this.sceneName,
      fullscreen: fullscreen ?? this.fullscreen,
      unloadOnDispose: unloadOnDispose ?? this.unloadOnDispose,
      hideStatusBar: hideStatusBar ?? this.hideStatusBar,
      runImmediately: runImmediately ?? this.runImmediately,
      targetFrameRate: targetFrameRate ?? this.targetFrameRate,
      platformViewMode: platformViewMode ?? this.platformViewMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnityConfig &&
          runtimeType == other.runtimeType &&
          sceneName == other.sceneName &&
          fullscreen == other.fullscreen &&
          unloadOnDispose == other.unloadOnDispose &&
          hideStatusBar == other.hideStatusBar &&
          runImmediately == other.runImmediately &&
          targetFrameRate == other.targetFrameRate &&
          platformViewMode == other.platformViewMode;

  @override
  int get hashCode => Object.hash(
        sceneName,
        fullscreen,
        unloadOnDispose,
        hideStatusBar,
        runImmediately,
        targetFrameRate,
        platformViewMode,
      );

  @override
  String toString() =>
      'UnityConfig(sceneName: $sceneName, fullscreen: $fullscreen, '
      'targetFrameRate: $targetFrameRate)';
}
