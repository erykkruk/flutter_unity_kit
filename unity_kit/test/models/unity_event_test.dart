import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/models/unity_event.dart';
import 'package:unity_kit/src/models/unity_event_type.dart';
import 'package:unity_kit/src/models/unity_lifecycle_state.dart';

void main() {
  group('UnityEvent', () {
    group('constructor', () {
      test('creates instance with required parameters', () {
        final timestamp = DateTime(2024, 1, 1);
        const type = UnityEventType.created;

        final event = UnityEvent(type: type, timestamp: timestamp);

        expect(event.type, type);
        expect(event.timestamp, timestamp);
        expect(event.message, isNull);
        expect(event.error, isNull);
      });

      test('creates instance with all parameters', () {
        final timestamp = DateTime(2024, 1, 1);

        final event = UnityEvent(
          type: UnityEventType.error,
          timestamp: timestamp,
          message: 'test message',
          error: 'test error',
        );

        expect(event.type, UnityEventType.error);
        expect(event.timestamp, timestamp);
        expect(event.message, 'test message');
        expect(event.error, 'test error');
      });
    });

    group('created factory', () {
      test('creates event with created type', () {
        final before = DateTime.now();
        final event = UnityEvent.created();
        final after = DateTime.now();

        expect(event.type, UnityEventType.created);
        expect(
          event.timestamp.isAfter(before) ||
              event.timestamp.isAtSameMomentAs(before),
          isTrue,
        );
        expect(
          event.timestamp.isBefore(after) ||
              event.timestamp.isAtSameMomentAs(after),
          isTrue,
        );
        expect(event.message, isNull);
        expect(event.error, isNull);
      });
    });

    group('error factory', () {
      test('creates event with error type and message', () {
        final event = UnityEvent.error('Something went wrong');

        expect(event.type, UnityEventType.error);
        expect(event.error, 'Something went wrong');
        expect(event.message, isNull);
      });

      test('creates event with empty error message', () {
        final event = UnityEvent.error('');

        expect(event.type, UnityEventType.error);
        expect(event.error, '');
      });
    });

    group('sceneLoaded factory', () {
      test('creates event with sceneLoaded type and scene name', () {
        final event = UnityEvent.sceneLoaded('Level1');

        expect(event.type, UnityEventType.sceneLoaded);
        expect(event.message, 'Level1');
        expect(event.error, isNull);
      });
    });

    group('message factory', () {
      test('creates event with message type and content', () {
        final event = UnityEvent.message('hello from unity');

        expect(event.type, UnityEventType.message);
        expect(event.message, 'hello from unity');
        expect(event.error, isNull);
      });
    });

    group('fromState factory', () {
      test('maps initializing to created', () {
        final event = UnityEvent.fromState(UnityLifecycleState.initializing);

        expect(event.type, UnityEventType.created);
      });

      test('maps ready to loaded', () {
        final event = UnityEvent.fromState(UnityLifecycleState.ready);

        expect(event.type, UnityEventType.loaded);
      });

      test('maps paused to paused', () {
        final event = UnityEvent.fromState(UnityLifecycleState.paused);

        expect(event.type, UnityEventType.paused);
      });

      test('maps resumed to resumed', () {
        final event = UnityEvent.fromState(UnityLifecycleState.resumed);

        expect(event.type, UnityEventType.resumed);
      });

      test('maps disposed to destroyed', () {
        final event = UnityEvent.fromState(UnityLifecycleState.disposed);

        expect(event.type, UnityEventType.destroyed);
      });

      test('maps uninitialized to unloaded', () {
        final event = UnityEvent.fromState(UnityLifecycleState.uninitialized);

        expect(event.type, UnityEventType.unloaded);
      });

      test('all lifecycle states produce valid events', () {
        for (final state in UnityLifecycleState.values) {
          final event = UnityEvent.fromState(state);

          expect(event.type, isNotNull);
          expect(event.timestamp, isNotNull);
        }
      });

      test('sets timestamp to current time', () {
        final before = DateTime.now();
        final event = UnityEvent.fromState(UnityLifecycleState.ready);
        final after = DateTime.now();

        expect(
          event.timestamp.isAfter(before) ||
              event.timestamp.isAtSameMomentAs(before),
          isTrue,
        );
        expect(
          event.timestamp.isBefore(after) ||
              event.timestamp.isAtSameMomentAs(after),
          isTrue,
        );
      });
    });

    group('toString', () {
      test('returns formatted string with all fields', () {
        final event = UnityEvent(
          type: UnityEventType.error,
          timestamp: DateTime(2024, 1, 1),
          message: 'msg',
          error: 'err',
        );

        expect(
          event.toString(),
          'UnityEvent(type: UnityEventType.error, message: msg, error: err)',
        );
      });

      test('returns formatted string with null fields', () {
        final event = UnityEvent(
          type: UnityEventType.created,
          timestamp: DateTime(2024, 1, 1),
        );

        expect(
          event.toString(),
          'UnityEvent(type: UnityEventType.created, message: null, error: null)',
        );
      });

      test('returns formatted string for message event', () {
        final event = UnityEvent(
          type: UnityEventType.message,
          timestamp: DateTime(2024, 1, 1),
          message: 'hello',
        );

        expect(
          event.toString(),
          'UnityEvent(type: UnityEventType.message, message: hello, error: null)',
        );
      });
    });
  });
}
