import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/models/unity_performance_stats.dart';

void main() {
  group('UnityPerformanceStats', () {
    test('defaults to zeros', () {
      const stats = UnityPerformanceStats();
      expect(stats.fps, 0);
      expect(stats.frameTimeMs, 0);
      expect(stats.usedMemoryMb, 0);
      expect(stats.drawCalls, 0);
      expect(stats.triangles, 0);
    });

    test('fromMap reads numeric fields', () {
      final stats = UnityPerformanceStats.fromMap({
        'fps': 59.94,
        'frameTimeMs': 16.7,
        'usedMemoryMb': 128,
        'drawCalls': 42,
        'triangles': 12000,
      });

      expect(stats.fps, closeTo(59.94, 1e-6));
      expect(stats.frameTimeMs, closeTo(16.7, 1e-6));
      expect(stats.usedMemoryMb, 128);
      expect(stats.drawCalls, 42);
      expect(stats.triangles, 12000);
    });

    test('fromMap tolerates strings and missing keys', () {
      final stats = UnityPerformanceStats.fromMap({
        'fps': '30',
        'drawCalls': '7',
      });

      expect(stats.fps, 30);
      expect(stats.drawCalls, 7);
      expect(stats.frameTimeMs, 0);
      expect(stats.triangles, 0);
    });

    test('toMap mirrors fromMap', () {
      const stats = UnityPerformanceStats(
        fps: 60,
        frameTimeMs: 16.6,
        usedMemoryMb: 200,
        drawCalls: 10,
        triangles: 500,
      );

      expect(UnityPerformanceStats.fromMap(stats.toMap()), stats);
    });

    test('value equality', () {
      const a = UnityPerformanceStats(fps: 60, drawCalls: 5);
      const b = UnityPerformanceStats(fps: 60, drawCalls: 5);
      const c = UnityPerformanceStats(fps: 30, drawCalls: 5);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
