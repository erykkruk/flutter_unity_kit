import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/bridge/readiness_guard.dart';
import 'package:unity_kit/src/exceptions/exceptions.dart';
import 'package:unity_kit/src/models/unity_message.dart';

void main() {
  late ReadinessGuard guard;

  setUp(() {
    guard = ReadinessGuard();
  });

  group('ReadinessGuard', () {
    group('initial state', () {
      test('isReady is false', () {
        expect(guard.isReady, isFalse);
      });

      test('queueLength is zero', () {
        expect(guard.queueLength, 0);
      });
    });

    group('guard()', () {
      test('throws EngineNotReadyException when not ready', () {
        expect(() => guard.guard(), throwsA(isA<EngineNotReadyException>()));
      });

      test('does not throw when ready', () async {
        await guard.markReady();

        expect(() => guard.guard(), returnsNormally);
      });
    });

    group('queueUntilReady()', () {
      test('sends immediately when ready', () async {
        await guard.markReady();

        final sent = <UnityMessage>[];
        final message = UnityMessage.command('TestAction');

        guard.queueUntilReady(message, (msg) async => sent.add(msg));

        expect(sent, hasLength(1));
        expect(sent.first.type, 'TestAction');
        expect(guard.queueLength, 0);
      });

      test('queues message when not ready', () {
        final message = UnityMessage.command('TestAction');

        guard.queueUntilReady(message, (msg) async {});

        expect(guard.queueLength, 1);
      });

      test('queues multiple messages in order', () {
        for (var i = 0; i < 3; i++) {
          guard.queueUntilReady(
            UnityMessage.command('Action$i'),
            (msg) async {},
          );
        }

        expect(guard.queueLength, 3);
      });
    });

    group('markReady()', () {
      test('sets isReady to true', () async {
        await guard.markReady();

        expect(guard.isReady, isTrue);
      });

      test('flushes all queued messages in order', () async {
        final sent = <String>[];

        for (var i = 0; i < 3; i++) {
          guard.queueUntilReady(
            UnityMessage.command('Action$i'),
            (msg) async => sent.add(msg.type),
          );
        }

        await guard.markReady();

        expect(sent, ['Action0', 'Action1', 'Action2']);
        expect(guard.queueLength, 0);
      });

      test('clears queue after flushing', () async {
        guard.queueUntilReady(
          UnityMessage.command('TestAction'),
          (msg) async {},
        );

        await guard.markReady();

        expect(guard.queueLength, 0);
      });
    });

    group('maxQueueSize', () {
      test('drops oldest message when queue is full', () {
        guard = ReadinessGuard(maxQueueSize: 3);

        for (var i = 0; i < 4; i++) {
          guard.queueUntilReady(
            UnityMessage.command('Action$i'),
            (msg) async {},
          );
        }

        expect(guard.queueLength, 3);
      });

      test('preserves newest messages when dropping', () async {
        guard = ReadinessGuard(maxQueueSize: 2);
        final sent = <String>[];

        for (var i = 0; i < 4; i++) {
          guard.queueUntilReady(
            UnityMessage.command('Action$i'),
            (msg) async => sent.add(msg.type),
          );
        }

        await guard.markReady();

        expect(sent, ['Action2', 'Action3']);
      });
    });

    group('reset()', () {
      test('sets isReady back to false', () async {
        await guard.markReady();
        guard.reset();

        expect(guard.isReady, isFalse);
      });

      test('guard() throws after reset', () async {
        await guard.markReady();
        guard.reset();

        expect(() => guard.guard(), throwsA(isA<EngineNotReadyException>()));
      });

      test('clears queued messages (DART-L4)', () {
        guard.queueUntilReady(
          UnityMessage.command('Msg1'),
          (msg) async {},
        );
        guard.queueUntilReady(
          UnityMessage.command('Msg2'),
          (msg) async {},
        );
        expect(guard.queueLength, 2);

        guard.reset();

        expect(guard.queueLength, 0);
      });

      test('does not flush cleared queue on markReady (DART-L4)', () async {
        final sent = <String>[];

        guard.queueUntilReady(
          UnityMessage.command('BeforeReset'),
          (msg) async => sent.add(msg.type),
        );

        guard.reset();
        await guard.markReady();

        expect(sent, isEmpty);
      });
    });

    group('dispose()', () {
      test('clears all queued messages', () {
        for (var i = 0; i < 5; i++) {
          guard.queueUntilReady(
            UnityMessage.command('Action$i'),
            (msg) async {},
          );
        }

        guard.dispose();

        expect(guard.queueLength, 0);
      });
    });
  });
}
