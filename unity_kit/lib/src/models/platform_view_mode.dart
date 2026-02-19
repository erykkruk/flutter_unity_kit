/// Platform view rendering mode for Android.
///
/// Controls how the Unity view is composited with Flutter widgets.
enum PlatformViewMode {
  /// Hybrid composition (default). Best compatibility, slight performance cost.
  hybridComposition,

  /// Virtual display. Better performance, potential input/z-ordering issues.
  virtualDisplay,

  /// Texture layer. Best performance, limited platform support.
  textureLayer,
}

/// Extensions for [PlatformViewMode].
extension PlatformViewModeExtension on PlatformViewMode {
  /// Human-readable description of this mode.
  String get description {
    switch (this) {
      case PlatformViewMode.hybridComposition:
        return 'Hybrid Composition (default, best compatibility)';
      case PlatformViewMode.virtualDisplay:
        return 'Virtual Display (better performance)';
      case PlatformViewMode.textureLayer:
        return 'Texture Layer (best performance, limited support)';
    }
  }

  /// Whether this is the default platform view mode.
  bool get isDefault => this == PlatformViewMode.hybridComposition;
}
