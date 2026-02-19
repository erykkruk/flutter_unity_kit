import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/models/unity_event_type.dart';

void main() {
  group('UnityEventType', () {
    test('has all expected values', () {
      expect(UnityEventType.values, hasLength(9));
    });

    test('contains created', () {
      expect(UnityEventType.values, contains(UnityEventType.created));
    });

    test('contains loaded', () {
      expect(UnityEventType.values, contains(UnityEventType.loaded));
    });

    test('contains paused', () {
      expect(UnityEventType.values, contains(UnityEventType.paused));
    });

    test('contains resumed', () {
      expect(UnityEventType.values, contains(UnityEventType.resumed));
    });

    test('contains unloaded', () {
      expect(UnityEventType.values, contains(UnityEventType.unloaded));
    });

    test('contains destroyed', () {
      expect(UnityEventType.values, contains(UnityEventType.destroyed));
    });

    test('contains error', () {
      expect(UnityEventType.values, contains(UnityEventType.error));
    });

    test('contains message', () {
      expect(UnityEventType.values, contains(UnityEventType.message));
    });

    test('contains sceneLoaded', () {
      expect(UnityEventType.values, contains(UnityEventType.sceneLoaded));
    });

    test('enum values have correct names', () {
      expect(UnityEventType.created.name, 'created');
      expect(UnityEventType.loaded.name, 'loaded');
      expect(UnityEventType.paused.name, 'paused');
      expect(UnityEventType.resumed.name, 'resumed');
      expect(UnityEventType.unloaded.name, 'unloaded');
      expect(UnityEventType.destroyed.name, 'destroyed');
      expect(UnityEventType.error.name, 'error');
      expect(UnityEventType.message.name, 'message');
      expect(UnityEventType.sceneLoaded.name, 'sceneLoaded');
    });
  });
}
