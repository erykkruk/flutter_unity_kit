import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/models/unity_lifecycle_state.dart';

void main() {
  group('UnityLifecycleState', () {
    test('has all expected values', () {
      expect(UnityLifecycleState.values, hasLength(6));
      expect(
        UnityLifecycleState.values,
        containsAll([
          UnityLifecycleState.uninitialized,
          UnityLifecycleState.initializing,
          UnityLifecycleState.ready,
          UnityLifecycleState.paused,
          UnityLifecycleState.resumed,
          UnityLifecycleState.disposed,
        ]),
      );
    });
  });

  group('UnityLifecycleStateExtension', () {
    group('isActive', () {
      test('returns true for ready state', () {
        expect(UnityLifecycleState.ready.isActive, isTrue);
      });

      test('returns true for resumed state', () {
        expect(UnityLifecycleState.resumed.isActive, isTrue);
      });

      test('returns false for uninitialized state', () {
        expect(UnityLifecycleState.uninitialized.isActive, isFalse);
      });

      test('returns false for initializing state', () {
        expect(UnityLifecycleState.initializing.isActive, isFalse);
      });

      test('returns false for paused state', () {
        expect(UnityLifecycleState.paused.isActive, isFalse);
      });

      test('returns false for disposed state', () {
        expect(UnityLifecycleState.disposed.isActive, isFalse);
      });
    });

    group('canSend', () {
      test('returns true for ready state', () {
        expect(UnityLifecycleState.ready.canSend, isTrue);
      });

      test('returns true for resumed state', () {
        expect(UnityLifecycleState.resumed.canSend, isTrue);
      });

      test('returns false for all inactive states', () {
        expect(UnityLifecycleState.uninitialized.canSend, isFalse);
        expect(UnityLifecycleState.initializing.canSend, isFalse);
        expect(UnityLifecycleState.paused.canSend, isFalse);
        expect(UnityLifecycleState.disposed.canSend, isFalse);
      });
    });

    group('canTransitionTo', () {
      group('from uninitialized', () {
        test('can transition to initializing', () {
          expect(
            UnityLifecycleState.uninitialized
                .canTransitionTo(UnityLifecycleState.initializing),
            isTrue,
          );
        });

        test('cannot transition to other states', () {
          expect(
            UnityLifecycleState.uninitialized
                .canTransitionTo(UnityLifecycleState.ready),
            isFalse,
          );
          expect(
            UnityLifecycleState.uninitialized
                .canTransitionTo(UnityLifecycleState.paused),
            isFalse,
          );
          expect(
            UnityLifecycleState.uninitialized
                .canTransitionTo(UnityLifecycleState.resumed),
            isFalse,
          );
          expect(
            UnityLifecycleState.uninitialized
                .canTransitionTo(UnityLifecycleState.disposed),
            isFalse,
          );
        });
      });

      group('from initializing', () {
        test('can transition to ready', () {
          expect(
            UnityLifecycleState.initializing
                .canTransitionTo(UnityLifecycleState.ready),
            isTrue,
          );
        });

        test('can transition to disposed', () {
          expect(
            UnityLifecycleState.initializing
                .canTransitionTo(UnityLifecycleState.disposed),
            isTrue,
          );
        });

        test('cannot transition to other states', () {
          expect(
            UnityLifecycleState.initializing
                .canTransitionTo(UnityLifecycleState.uninitialized),
            isFalse,
          );
          expect(
            UnityLifecycleState.initializing
                .canTransitionTo(UnityLifecycleState.paused),
            isFalse,
          );
          expect(
            UnityLifecycleState.initializing
                .canTransitionTo(UnityLifecycleState.resumed),
            isFalse,
          );
        });
      });

      group('from ready', () {
        test('can transition to paused', () {
          expect(
            UnityLifecycleState.ready
                .canTransitionTo(UnityLifecycleState.paused),
            isTrue,
          );
        });

        test('can transition to disposed', () {
          expect(
            UnityLifecycleState.ready
                .canTransitionTo(UnityLifecycleState.disposed),
            isTrue,
          );
        });

        test('cannot transition to other states', () {
          expect(
            UnityLifecycleState.ready
                .canTransitionTo(UnityLifecycleState.uninitialized),
            isFalse,
          );
          expect(
            UnityLifecycleState.ready
                .canTransitionTo(UnityLifecycleState.initializing),
            isFalse,
          );
          expect(
            UnityLifecycleState.ready
                .canTransitionTo(UnityLifecycleState.resumed),
            isFalse,
          );
        });
      });

      group('from paused', () {
        test('can transition to resumed', () {
          expect(
            UnityLifecycleState.paused
                .canTransitionTo(UnityLifecycleState.resumed),
            isTrue,
          );
        });

        test('can transition to disposed', () {
          expect(
            UnityLifecycleState.paused
                .canTransitionTo(UnityLifecycleState.disposed),
            isTrue,
          );
        });

        test('cannot transition to other states', () {
          expect(
            UnityLifecycleState.paused
                .canTransitionTo(UnityLifecycleState.uninitialized),
            isFalse,
          );
          expect(
            UnityLifecycleState.paused
                .canTransitionTo(UnityLifecycleState.initializing),
            isFalse,
          );
          expect(
            UnityLifecycleState.paused
                .canTransitionTo(UnityLifecycleState.ready),
            isFalse,
          );
        });
      });

      group('from resumed', () {
        test('can transition to paused', () {
          expect(
            UnityLifecycleState.resumed
                .canTransitionTo(UnityLifecycleState.paused),
            isTrue,
          );
        });

        test('can transition to disposed', () {
          expect(
            UnityLifecycleState.resumed
                .canTransitionTo(UnityLifecycleState.disposed),
            isTrue,
          );
        });

        test('cannot transition to other states', () {
          expect(
            UnityLifecycleState.resumed
                .canTransitionTo(UnityLifecycleState.uninitialized),
            isFalse,
          );
          expect(
            UnityLifecycleState.resumed
                .canTransitionTo(UnityLifecycleState.initializing),
            isFalse,
          );
          expect(
            UnityLifecycleState.resumed
                .canTransitionTo(UnityLifecycleState.ready),
            isFalse,
          );
        });
      });

      group('from disposed', () {
        test('cannot transition to any state', () {
          for (final state in UnityLifecycleState.values) {
            expect(
              UnityLifecycleState.disposed.canTransitionTo(state),
              isFalse,
              reason: 'disposed should not transition to $state',
            );
          }
        });
      });
    });
  });
}
