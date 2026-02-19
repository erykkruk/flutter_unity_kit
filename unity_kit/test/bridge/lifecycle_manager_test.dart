import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/bridge/lifecycle_manager.dart';
import 'package:unity_kit/src/exceptions/lifecycle_exception.dart';
import 'package:unity_kit/src/models/unity_event.dart';
import 'package:unity_kit/src/models/unity_event_type.dart';
import 'package:unity_kit/src/models/unity_lifecycle_state.dart';

void main() {
  late LifecycleManager manager;

  setUp(() {
    manager = LifecycleManager();
  });

  tearDown(() {
    manager.dispose();
  });

  group('LifecycleManager', () {
    group('initial state', () {
      test('starts in uninitialized state', () {
        expect(manager.currentState, UnityLifecycleState.uninitialized);
      });

      test('is not active initially', () {
        expect(manager.isActive, isFalse);
      });
    });

    group('valid transitions', () {
      test('uninitialized -> initializing', () {
        manager.transition(UnityLifecycleState.initializing);

        expect(manager.currentState, UnityLifecycleState.initializing);
      });

      test('initializing -> ready', () {
        manager.transition(UnityLifecycleState.initializing);
        manager.transition(UnityLifecycleState.ready);

        expect(manager.currentState, UnityLifecycleState.ready);
      });

      test('initializing -> disposed', () {
        manager.transition(UnityLifecycleState.initializing);
        manager.transition(UnityLifecycleState.disposed);

        expect(manager.currentState, UnityLifecycleState.disposed);
      });

      test('ready -> paused', () {
        manager.transition(UnityLifecycleState.initializing);
        manager.transition(UnityLifecycleState.ready);
        manager.transition(UnityLifecycleState.paused);

        expect(manager.currentState, UnityLifecycleState.paused);
      });

      test('ready -> disposed', () {
        manager.transition(UnityLifecycleState.initializing);
        manager.transition(UnityLifecycleState.ready);
        manager.transition(UnityLifecycleState.disposed);

        expect(manager.currentState, UnityLifecycleState.disposed);
      });

      test('paused -> resumed', () {
        manager.transition(UnityLifecycleState.initializing);
        manager.transition(UnityLifecycleState.ready);
        manager.transition(UnityLifecycleState.paused);
        manager.transition(UnityLifecycleState.resumed);

        expect(manager.currentState, UnityLifecycleState.resumed);
      });

      test('paused -> disposed', () {
        manager.transition(UnityLifecycleState.initializing);
        manager.transition(UnityLifecycleState.ready);
        manager.transition(UnityLifecycleState.paused);
        manager.transition(UnityLifecycleState.disposed);

        expect(manager.currentState, UnityLifecycleState.disposed);
      });

      test('resumed -> paused', () {
        manager.transition(UnityLifecycleState.initializing);
        manager.transition(UnityLifecycleState.ready);
        manager.transition(UnityLifecycleState.paused);
        manager.transition(UnityLifecycleState.resumed);
        manager.transition(UnityLifecycleState.paused);

        expect(manager.currentState, UnityLifecycleState.paused);
      });

      test('resumed -> disposed', () {
        manager.transition(UnityLifecycleState.initializing);
        manager.transition(UnityLifecycleState.ready);
        manager.transition(UnityLifecycleState.paused);
        manager.transition(UnityLifecycleState.resumed);
        manager.transition(UnityLifecycleState.disposed);

        expect(manager.currentState, UnityLifecycleState.disposed);
      });

      test('full lifecycle: init -> ready -> pause -> resume -> dispose', () {
        manager.transition(UnityLifecycleState.initializing);
        manager.transition(UnityLifecycleState.ready);
        manager.transition(UnityLifecycleState.paused);
        manager.transition(UnityLifecycleState.resumed);
        manager.transition(UnityLifecycleState.disposed);

        expect(manager.currentState, UnityLifecycleState.disposed);
      });
    });

    group('invalid transitions', () {
      test('uninitialized -> ready throws LifecycleException', () {
        expect(
          () => manager.transition(UnityLifecycleState.ready),
          throwsA(isA<LifecycleException>()),
        );
      });

      test('uninitialized -> paused throws LifecycleException', () {
        expect(
          () => manager.transition(UnityLifecycleState.paused),
          throwsA(isA<LifecycleException>()),
        );
      });

      test('uninitialized -> disposed throws LifecycleException', () {
        expect(
          () => manager.transition(UnityLifecycleState.disposed),
          throwsA(isA<LifecycleException>()),
        );
      });

      test('disposed -> any state throws LifecycleException', () {
        manager.transition(UnityLifecycleState.initializing);
        manager.transition(UnityLifecycleState.disposed);

        for (final state in UnityLifecycleState.values) {
          expect(
            () => manager.transition(state),
            throwsA(isA<LifecycleException>()),
            reason: 'disposed should not transition to $state',
          );
        }
      });

      test('ready -> initializing throws LifecycleException', () {
        manager.transition(UnityLifecycleState.initializing);
        manager.transition(UnityLifecycleState.ready);

        expect(
          () => manager.transition(UnityLifecycleState.initializing),
          throwsA(isA<LifecycleException>()),
        );
      });

      test('exception contains current state and attempted action', () {
        try {
          manager.transition(UnityLifecycleState.ready);
          fail('Expected LifecycleException');
        } on LifecycleException catch (e) {
          expect(e.currentState, UnityLifecycleState.uninitialized);
          expect(e.attemptedAction, contains('ready'));
        }
      });

      test('state does not change on invalid transition', () {
        expect(manager.currentState, UnityLifecycleState.uninitialized);

        expect(
          () => manager.transition(UnityLifecycleState.ready),
          throwsA(isA<LifecycleException>()),
        );

        expect(manager.currentState, UnityLifecycleState.uninitialized);
      });
    });

    group('stateStream', () {
      test('emits state on valid transition', () async {
        final states = <UnityLifecycleState>[];
        manager.stateStream.listen(states.add);

        manager.transition(UnityLifecycleState.initializing);
        manager.transition(UnityLifecycleState.ready);

        await Future<void>.delayed(Duration.zero);

        expect(states, [
          UnityLifecycleState.initializing,
          UnityLifecycleState.ready,
        ]);
      });

      test('does not emit on invalid transition', () async {
        final states = <UnityLifecycleState>[];
        manager.stateStream.listen(states.add);

        try {
          manager.transition(UnityLifecycleState.ready);
        } on LifecycleException {
          // Expected.
        }

        await Future<void>.delayed(Duration.zero);

        expect(states, isEmpty);
      });

      test('supports multiple listeners (broadcast)', () async {
        final statesA = <UnityLifecycleState>[];
        final statesB = <UnityLifecycleState>[];
        manager.stateStream.listen(statesA.add);
        manager.stateStream.listen(statesB.add);

        manager.transition(UnityLifecycleState.initializing);

        await Future<void>.delayed(Duration.zero);

        expect(statesA, [UnityLifecycleState.initializing]);
        expect(statesB, [UnityLifecycleState.initializing]);
      });
    });

    group('eventStream', () {
      test('emits UnityEvent on valid transition', () async {
        final events = <UnityEvent>[];
        manager.eventStream.listen(events.add);

        manager.transition(UnityLifecycleState.initializing);

        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.first.type, UnityEventType.created);
      });

      test('emits correct event types for full lifecycle', () async {
        final events = <UnityEvent>[];
        manager.eventStream.listen(events.add);

        manager.transition(UnityLifecycleState.initializing);
        manager.transition(UnityLifecycleState.ready);
        manager.transition(UnityLifecycleState.paused);
        manager.transition(UnityLifecycleState.resumed);
        manager.transition(UnityLifecycleState.disposed);

        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(5));
        expect(events[0].type, UnityEventType.created);
        expect(events[1].type, UnityEventType.loaded);
        expect(events[2].type, UnityEventType.paused);
        expect(events[3].type, UnityEventType.resumed);
        expect(events[4].type, UnityEventType.destroyed);
      });

      test('does not emit on invalid transition', () async {
        final events = <UnityEvent>[];
        manager.eventStream.listen(events.add);

        try {
          manager.transition(UnityLifecycleState.disposed);
        } on LifecycleException {
          // Expected.
        }

        await Future<void>.delayed(Duration.zero);

        expect(events, isEmpty);
      });
    });

    group('isActive', () {
      test('returns false for uninitialized', () {
        expect(manager.isActive, isFalse);
      });

      test('returns false for initializing', () {
        manager.transition(UnityLifecycleState.initializing);

        expect(manager.isActive, isFalse);
      });

      test('returns true for ready', () {
        manager.transition(UnityLifecycleState.initializing);
        manager.transition(UnityLifecycleState.ready);

        expect(manager.isActive, isTrue);
      });

      test('returns false for paused', () {
        manager.transition(UnityLifecycleState.initializing);
        manager.transition(UnityLifecycleState.ready);
        manager.transition(UnityLifecycleState.paused);

        expect(manager.isActive, isFalse);
      });

      test('returns true for resumed', () {
        manager.transition(UnityLifecycleState.initializing);
        manager.transition(UnityLifecycleState.ready);
        manager.transition(UnityLifecycleState.paused);
        manager.transition(UnityLifecycleState.resumed);

        expect(manager.isActive, isTrue);
      });

      test('returns false for disposed', () {
        manager.transition(UnityLifecycleState.initializing);
        manager.transition(UnityLifecycleState.disposed);

        expect(manager.isActive, isFalse);
      });
    });

    group('reset', () {
      test('returns to uninitialized state', () {
        manager.transition(UnityLifecycleState.initializing);
        manager.transition(UnityLifecycleState.ready);

        manager.reset();

        expect(manager.currentState, UnityLifecycleState.uninitialized);
      });

      test('allows new lifecycle after reset', () {
        manager.transition(UnityLifecycleState.initializing);
        manager.transition(UnityLifecycleState.disposed);

        manager.reset();

        manager.transition(UnityLifecycleState.initializing);
        manager.transition(UnityLifecycleState.ready);

        expect(manager.currentState, UnityLifecycleState.ready);
      });

      test('does not emit on stateStream', () async {
        final states = <UnityLifecycleState>[];
        manager.stateStream.listen(states.add);

        manager.transition(UnityLifecycleState.initializing);
        manager.reset();

        await Future<void>.delayed(Duration.zero);

        expect(states, [UnityLifecycleState.initializing]);
      });
    });

    group('dispose', () {
      test('closes stateStream', () async {
        final manager = LifecycleManager();

        manager.transition(UnityLifecycleState.initializing);
        manager.dispose();

        expect(
          manager.stateStream.isEmpty,
          completion(isTrue),
        );
      });

      test('closes eventStream', () async {
        final manager = LifecycleManager();

        manager.transition(UnityLifecycleState.initializing);
        manager.dispose();

        expect(
          manager.eventStream.isEmpty,
          completion(isTrue),
        );
      });
    });
  });
}
