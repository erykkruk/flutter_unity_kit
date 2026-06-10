/// AR rendering mode for a Unity view backed by AR Foundation.
///
/// Controls whether Unity drives an augmented-reality session and how its
/// camera feed is composited. The actual AR session runs inside the Unity
/// project (AR Foundation + ARCore/ARKit); this enum is the Flutter-side
/// switch that the native host and the Unity bridge honour.
enum UnityArMode {
  /// No AR. Unity renders normally against its own background.
  none,

  /// AR with the device camera feed rendered by Unity behind the scene.
  ///
  /// Use this for fully Unity-driven AR experiences.
  passthrough,

  /// AR session active, but Unity clears to a transparent background so the
  /// camera feed (or Flutter content) shows through from behind the surface.
  ///
  /// Pair with `UnityConfig.transparentBackground` for hybrid AR overlays.
  overlay,
}

/// Extensions for [UnityArMode].
extension UnityArModeExtension on UnityArMode {
  /// Whether this mode requires an active AR session.
  bool get isArActive => this != UnityArMode.none;

  /// Stable wire name passed to the native host and Unity bridge.
  String get wireName => switch (this) {
        UnityArMode.none => 'none',
        UnityArMode.passthrough => 'passthrough',
        UnityArMode.overlay => 'overlay',
      };

  /// Parses a [UnityArMode] from its [wireName], defaulting to [none].
  static UnityArMode fromWireName(String? value) => switch (value) {
        'passthrough' => UnityArMode.passthrough,
        'overlay' => UnityArMode.overlay,
        _ => UnityArMode.none,
      };
}
