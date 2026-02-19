import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/bridge/message_batcher.dart';
import 'package:unity_kit/src/models/unity_message.dart';

void main() {
  group('MessageBatcher', () {
    group('add()', () {
      test('queues message as pending', () {
        final batcher = MessageBatcher(
          onFlush: (messages) async {},
        );
        addTearDown(batcher.dispose);

        batcher.add(const UnityMessage(type: 'Move', data: {'x': 1.0}));

        expect(batcher.pendingCount, 1);
      });

      test('increments totalBatched', () {
        final batcher = MessageBatcher(
          onFlush: (messages) async {},
        );
        addTearDown(batcher.dispose);

        batcher.add(const UnityMessage(type: 'Move'));
        batcher.add(const UnityMessage(type: 'Rotate'));

        expect(batcher.totalBatched, 2);
      });

      test('after dispose is no-op', () {
        final batcher = MessageBatcher(
          onFlush: (messages) async {},
        );

        batcher.dispose();
        batcher.add(const UnityMessage(type: 'Move'));

        expect(batcher.pendingCount, 0);
        expect(batcher.totalBatched, 0);
      });
    });

    group('flush()', () {
      test('sends all pending messages and clears queue', () {
        final flushed = <List<UnityMessage>>[];
        final batcher = MessageBatcher(
          onFlush: (messages) async => flushed.add(messages),
        );
        addTearDown(batcher.dispose);

        batcher.add(UnityMessage.to('Player', 'Move', {'x': 1.0}));
        batcher.add(UnityMessage.to('Camera', 'Rotate', {'angle': 90}));
        batcher.flush();

        expect(flushed, hasLength(1));
        expect(flushed.first, hasLength(2));
        expect(batcher.pendingCount, 0);
      });

      test('with no pending messages is no-op', () {
        var flushCount = 0;
        final batcher = MessageBatcher(
          onFlush: (messages) async => flushCount++,
        );
        addTearDown(batcher.dispose);

        batcher.flush();

        expect(flushCount, 0);
      });

      test('updates totalFlushed statistic', () {
        final batcher = MessageBatcher(
          onFlush: (messages) async {},
        );
        addTearDown(batcher.dispose);

        batcher.add(UnityMessage.to('Player', 'Move'));
        batcher.add(UnityMessage.to('Camera', 'Rotate'));
        batcher.flush();

        expect(batcher.totalFlushed, 2);
      });
    });

    group('timer flush', () {
      test('triggers flush after interval', () {
        fakeAsync((async) {
          final flushed = <List<UnityMessage>>[];
          final batcher = MessageBatcher(
            flushInterval: const Duration(milliseconds: 16),
            onFlush: (messages) async => flushed.add(messages),
          );

          batcher.add(const UnityMessage(type: 'Move', data: {'x': 1.0}));
          expect(flushed, isEmpty);

          async.elapse(const Duration(milliseconds: 16));

          expect(flushed, hasLength(1));
          expect(flushed.first, hasLength(1));
          expect(batcher.pendingCount, 0);

          batcher.dispose();
        });
      });

      test('does not flush before interval elapses', () {
        fakeAsync((async) {
          final flushed = <List<UnityMessage>>[];
          final batcher = MessageBatcher(
            flushInterval: const Duration(milliseconds: 100),
            onFlush: (messages) async => flushed.add(messages),
          );

          batcher.add(const UnityMessage(type: 'Move'));

          async.elapse(const Duration(milliseconds: 50));

          expect(flushed, isEmpty);
          expect(batcher.pendingCount, 1);

          batcher.dispose();
        });
      });

      test('resets timer on manual flush', () {
        fakeAsync((async) {
          final flushed = <List<UnityMessage>>[];
          final batcher = MessageBatcher(
            flushInterval: const Duration(milliseconds: 100),
            onFlush: (messages) async => flushed.add(messages),
          );

          batcher.add(const UnityMessage(type: 'Move'));
          batcher.flush();

          async.elapse(const Duration(milliseconds: 100));

          // Only the manual flush should have fired, not a second timer flush.
          expect(flushed, hasLength(1));

          batcher.dispose();
        });
      });
    });

    group('coalescing', () {
      test('same gameObject:method key overwrites previous message', () {
        final flushed = <List<UnityMessage>>[];
        final batcher = MessageBatcher(
          onFlush: (messages) async => flushed.add(messages),
        );
        addTearDown(batcher.dispose);

        batcher.add(const UnityMessage(type: 'Move', data: {'x': 1.0}));
        batcher.add(const UnityMessage(type: 'Move', data: {'x': 5.0}));
        batcher.flush();

        expect(flushed, hasLength(1));
        expect(flushed.first, hasLength(1));
        expect(flushed.first.first.data, {'x': 5.0});
      });

      test('different keys accumulate separately', () {
        final flushed = <List<UnityMessage>>[];
        final batcher = MessageBatcher(
          onFlush: (messages) async => flushed.add(messages),
        );
        addTearDown(batcher.dispose);

        batcher.add(UnityMessage.to('Player', 'Move', {'x': 1.0}));
        batcher.add(UnityMessage.to('Camera', 'Pan', {'y': 2.0}));
        batcher.flush();

        expect(flushed.first, hasLength(2));
      });

      test('different methods on same gameObject accumulate', () {
        final flushed = <List<UnityMessage>>[];
        final batcher = MessageBatcher(
          onFlush: (messages) async => flushed.add(messages),
        );
        addTearDown(batcher.dispose);

        batcher.add(UnityMessage.to('Player', 'Move', {'x': 1.0}));
        batcher.add(UnityMessage.to('Player', 'Rotate', {'angle': 90}));
        batcher.flush();

        expect(flushed.first, hasLength(2));
      });
    });

    group('maxBatchSize', () {
      test('triggers immediate flush when reached', () {
        final flushed = <List<UnityMessage>>[];
        final batcher = MessageBatcher(
          maxBatchSize: 3,
          onFlush: (messages) async => flushed.add(messages),
        );
        addTearDown(batcher.dispose);

        batcher.add(UnityMessage.to('A', 'M1'));
        batcher.add(UnityMessage.to('B', 'M2'));
        batcher.add(UnityMessage.to('C', 'M3'));

        expect(flushed, hasLength(1));
        expect(flushed.first, hasLength(3));
        expect(batcher.pendingCount, 0);
      });

      test('does not flush before maxBatchSize', () {
        final flushed = <List<UnityMessage>>[];
        final batcher = MessageBatcher(
          maxBatchSize: 5,
          onFlush: (messages) async => flushed.add(messages),
        );
        addTearDown(batcher.dispose);

        batcher.add(UnityMessage.to('A', 'M1'));
        batcher.add(UnityMessage.to('B', 'M2'));

        expect(flushed, isEmpty);
        expect(batcher.pendingCount, 2);
      });
    });

    group('statistics', () {
      test('totalBatched counts all add() calls including coalesced', () {
        final batcher = MessageBatcher(
          onFlush: (messages) async {},
        );
        addTearDown(batcher.dispose);

        batcher.add(const UnityMessage(type: 'Move', data: {'x': 1.0}));
        batcher.add(const UnityMessage(type: 'Move', data: {'x': 2.0}));
        batcher.add(const UnityMessage(type: 'Move', data: {'x': 3.0}));

        expect(batcher.totalBatched, 3);
      });

      test('totalFlushed counts only actually sent messages', () {
        final batcher = MessageBatcher(
          onFlush: (messages) async {},
        );
        addTearDown(batcher.dispose);

        // Three adds but same key, so only 1 message flushed.
        batcher.add(const UnityMessage(type: 'Move', data: {'x': 1.0}));
        batcher.add(const UnityMessage(type: 'Move', data: {'x': 2.0}));
        batcher.add(const UnityMessage(type: 'Move', data: {'x': 3.0}));
        batcher.flush();

        expect(batcher.totalBatched, 3);
        expect(batcher.totalFlushed, 1);
      });

      test('averageBatchSize tracks correctly across multiple flushes', () {
        final batcher = MessageBatcher(
          onFlush: (messages) async {},
        );
        addTearDown(batcher.dispose);

        // First flush: 2 messages.
        batcher.add(UnityMessage.to('A', 'M1'));
        batcher.add(UnityMessage.to('B', 'M2'));
        batcher.flush();

        // Second flush: 4 messages.
        batcher.add(UnityMessage.to('C', 'M3'));
        batcher.add(UnityMessage.to('D', 'M4'));
        batcher.add(UnityMessage.to('E', 'M5'));
        batcher.add(UnityMessage.to('F', 'M6'));
        batcher.flush();

        // Average: (2 + 4) / 2 = 3.0
        expect(batcher.averageBatchSize, 3.0);
      });

      test('averageBatchSize returns 0 when no flushes occurred', () {
        final batcher = MessageBatcher(
          onFlush: (messages) async {},
        );
        addTearDown(batcher.dispose);

        expect(batcher.averageBatchSize, 0);
      });
    });

    group('dispose()', () {
      test('cancels timer and clears pending', () {
        fakeAsync((async) {
          final flushed = <List<UnityMessage>>[];
          final batcher = MessageBatcher(
            flushInterval: const Duration(milliseconds: 100),
            onFlush: (messages) async => flushed.add(messages),
          );

          batcher.add(const UnityMessage(type: 'Move'));
          batcher.dispose();

          async.elapse(const Duration(milliseconds: 100));

          expect(flushed, isEmpty);
          expect(batcher.pendingCount, 0);
        });
      });

      test('flush after dispose is no-op', () {
        var flushCount = 0;
        final batcher = MessageBatcher(
          onFlush: (messages) async => flushCount++,
        );

        batcher.add(const UnityMessage(type: 'Move'));
        batcher.dispose();
        batcher.flush();

        expect(flushCount, 0);
      });
    });

    group('flush error handling (DART-M2)', () {
      test('onFlush error does not crash batcher', () {
        final batcher = MessageBatcher(
          onFlush: (messages) async => throw Exception('Network error'),
        );
        addTearDown(batcher.dispose);

        batcher.add(UnityMessage.to('Player', 'Move', {'x': 1.0}));

        expect(() => batcher.flush(), returnsNormally);
        expect(batcher.pendingCount, 0);
        expect(batcher.totalFlushed, 1);
      });

      test('batcher continues working after onFlush error', () {
        var callCount = 0;
        final batcher = MessageBatcher(
          onFlush: (messages) async {
            callCount++;
            if (callCount == 1) throw Exception('First flush fails');
          },
        );
        addTearDown(batcher.dispose);

        batcher.add(UnityMessage.to('A', 'M1'));
        batcher.flush();

        batcher.add(UnityMessage.to('B', 'M2'));
        batcher.flush();

        expect(callCount, 2);
        expect(batcher.totalFlushed, 2);
      });

      test('timer flush error does not crash batcher', () {
        fakeAsync((async) {
          final batcher = MessageBatcher(
            flushInterval: const Duration(milliseconds: 16),
            onFlush: (messages) async => throw Exception('Timer flush error'),
          );

          batcher.add(const UnityMessage(type: 'Move'));

          expect(() => async.elapse(const Duration(milliseconds: 16)),
              returnsNormally);

          batcher.dispose();
        });
      });
    });

    group('pendingCount', () {
      test('reflects current queue size', () {
        final batcher = MessageBatcher(
          onFlush: (messages) async {},
        );
        addTearDown(batcher.dispose);

        expect(batcher.pendingCount, 0);

        batcher.add(UnityMessage.to('A', 'M1'));
        expect(batcher.pendingCount, 1);

        batcher.add(UnityMessage.to('B', 'M2'));
        expect(batcher.pendingCount, 2);

        batcher.flush();
        expect(batcher.pendingCount, 0);
      });

      test('does not increase for coalesced messages', () {
        final batcher = MessageBatcher(
          onFlush: (messages) async {},
        );
        addTearDown(batcher.dispose);

        batcher.add(const UnityMessage(type: 'Move', data: {'x': 1.0}));
        batcher.add(const UnityMessage(type: 'Move', data: {'x': 2.0}));

        expect(batcher.pendingCount, 1);
      });
    });
  });
}
