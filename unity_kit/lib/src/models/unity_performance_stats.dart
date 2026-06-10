/// A single performance sample reported by the Unity player.
///
/// Emitted on [UnityBridge.performanceStream] when a Unity-side performance
/// monitor pushes frame statistics. All fields are best-effort: a producer
/// may report only a subset, leaving the rest at their defaults.
///
/// Example:
/// ```dart
/// bridge.performanceStream.listen((stats) {
///   debugPrint('${stats.fps.toStringAsFixed(1)} fps, '
///       '${stats.frameTimeMs.toStringAsFixed(1)} ms');
/// });
/// ```
class UnityPerformanceStats {
  /// Creates a new [UnityPerformanceStats].
  const UnityPerformanceStats({
    this.fps = 0,
    this.frameTimeMs = 0,
    this.usedMemoryMb = 0,
    this.drawCalls = 0,
    this.triangles = 0,
  });

  /// Builds stats from a decoded message payload.
  ///
  /// Accepts both `int` and `double` JSON numbers for every field and
  /// tolerates missing keys.
  factory UnityPerformanceStats.fromMap(Map<String, dynamic> map) {
    double readDouble(String key) {
      final value = map[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0;
      return 0;
    }

    int readInt(String key) {
      final value = map[key];
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return UnityPerformanceStats(
      fps: readDouble('fps'),
      frameTimeMs: readDouble('frameTimeMs'),
      usedMemoryMb: readDouble('usedMemoryMb'),
      drawCalls: readInt('drawCalls'),
      triangles: readInt('triangles'),
    );
  }

  /// Frames rendered per second.
  final double fps;

  /// Time to render the last frame, in milliseconds.
  final double frameTimeMs;

  /// Total memory in use by Unity, in megabytes.
  final double usedMemoryMb;

  /// Number of draw calls in the last frame.
  final int drawCalls;

  /// Number of triangles rendered in the last frame.
  final int triangles;

  /// Serializes these stats to a map (mirrors [fromMap]).
  Map<String, dynamic> toMap() => {
        'fps': fps,
        'frameTimeMs': frameTimeMs,
        'usedMemoryMb': usedMemoryMb,
        'drawCalls': drawCalls,
        'triangles': triangles,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnityPerformanceStats &&
          runtimeType == other.runtimeType &&
          fps == other.fps &&
          frameTimeMs == other.frameTimeMs &&
          usedMemoryMb == other.usedMemoryMb &&
          drawCalls == other.drawCalls &&
          triangles == other.triangles;

  @override
  int get hashCode =>
      Object.hash(fps, frameTimeMs, usedMemoryMb, drawCalls, triangles);

  @override
  String toString() => 'UnityPerformanceStats(fps: ${fps.toStringAsFixed(1)}, '
      'frameTimeMs: ${frameTimeMs.toStringAsFixed(2)}, '
      'usedMemoryMb: ${usedMemoryMb.toStringAsFixed(1)}, '
      'drawCalls: $drawCalls, triangles: $triangles)';
}
