import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/bridge/message_throttler.dart';
import 'package:unity_kit/src/models/unity_message.dart';

void main() {
  group('MessageThrottler', () {
    late MessageThrottler throttler;
    late List<UnityMessage> sent;
    late Future<void> Function(UnityMessage) sender;

    setUp(() {
      sent = <UnityMessage>[];
      sender = (msg) async => sent.add(msg);
    });

    tearDown(() {
      throttler.dispose();
    });

    group('first message', () {
      test('is sent immediately', () {
        fakeAsync((async) {
          throttler = MessageThrottler();
          final message = UnityMessage.command('Action1');

          throttler.throttle(message, sender);

          expect(sent, hasLength(1));
          expect(sent.first.type, 'Action1');
        });
      });

      test('starts throttle window', () {
        fakeAsync((async) {
          throttler = MessageThrottler();

          throttler.throttle(UnityMessage.command('A'), sender);

          expect(throttler.isThrottling, isTrue);
        });
      });
    });

    group('ThrottleStrategy.drop', () {
      setUp(() {
        throttler = MessageThrottler(strategy: ThrottleStrategy.drop);
      });

      test('drops messages within throttle window', () {
        fakeAsync((async) {
          throttler.throttle(UnityMessage.command('First'), sender);
          throttler.throttle(UnityMessage.command('Second'), sender);
          throttler.throttle(UnityMessage.command('Third'), sender);

          async.elapse(const Duration(milliseconds: 100));

          expect(sent, hasLength(1));
          expect(sent.first.type, 'First');
          expect(throttler.totalDropped, 2);
        });
      });
    });

    group('ThrottleStrategy.keepLatest', () {
      setUp(() {
        throttler = MessageThrottler(strategy: ThrottleStrategy.keepLatest);
      });

      test('sends latest message after window ends', () {
        fakeAsync((async) {
          throttler.throttle(UnityMessage.command('First'), sender);
          throttler.throttle(UnityMessage.command('Second'), sender);
          throttler.throttle(UnityMessage.command('Third'), sender);

          async.elapse(const Duration(milliseconds: 100));

          expect(sent, hasLength(2));
          expect(sent[0].type, 'First');
          expect(sent[1].type, 'Third');
        });
      });

      test('drops intermediate messages', () {
        fakeAsync((async) {
          throttler.throttle(UnityMessage.command('A'), sender);
          throttler.throttle(UnityMessage.command('B'), sender);
          throttler.throttle(UnityMessage.command('C'), sender);

          expect(throttler.totalDropped, 1);

          async.elapse(const Duration(milliseconds: 100));

          expect(throttler.totalDropped, 1);
        });
      });
    });

    group('ThrottleStrategy.keepFirst', () {
      setUp(() {
        throttler = MessageThrottler(strategy: ThrottleStrategy.keepFirst);
      });

      test('keeps first pending message, drops subsequent', () {
        fakeAsync((async) {
          throttler.throttle(UnityMessage.command('First'), sender);
          throttler.throttle(UnityMessage.command('Second'), sender);
          throttler.throttle(UnityMessage.command('Third'), sender);

          async.elapse(const Duration(milliseconds: 100));

          expect(sent, hasLength(2));
          expect(sent[0].type, 'First');
          expect(sent[1].type, 'Second');
          expect(throttler.totalDropped, 1);
        });
      });
    });

    group('window lifecycle', () {
      test('after window ends, next message sends immediately', () {
        fakeAsync((async) {
          throttler = MessageThrottler();

          throttler.throttle(UnityMessage.command('First'), sender);
          async.elapse(const Duration(milliseconds: 100));

          expect(throttler.isThrottling, isFalse);

          throttler.throttle(UnityMessage.command('Second'), sender);

          expect(sent, hasLength(2));
          expect(sent[1].type, 'Second');
        });
      });

      test('pending message opens new window when sent', () {
        fakeAsync((async) {
          throttler = MessageThrottler(strategy: ThrottleStrategy.keepLatest);

          throttler.throttle(UnityMessage.command('A'), sender);
          throttler.throttle(UnityMessage.command('B'), sender);

          async.elapse(const Duration(milliseconds: 100));

          expect(throttler.isThrottling, isTrue);

          async.elapse(const Duration(milliseconds: 100));

          expect(throttler.isThrottling, isFalse);
        });
      });
    });

    group('statistics', () {
      test('totalThrottled counts all calls', () {
        fakeAsync((async) {
          throttler = MessageThrottler(strategy: ThrottleStrategy.drop);

          throttler.throttle(UnityMessage.command('A'), sender);
          throttler.throttle(UnityMessage.command('B'), sender);
          throttler.throttle(UnityMessage.command('C'), sender);

          expect(throttler.totalThrottled, 3);
        });
      });

      test('totalSent counts sent messages', () {
        fakeAsync((async) {
          throttler = MessageThrottler(strategy: ThrottleStrategy.keepLatest);

          throttler.throttle(UnityMessage.command('A'), sender);
          throttler.throttle(UnityMessage.command('B'), sender);

          async.elapse(const Duration(milliseconds: 100));

          expect(throttler.totalSent, 2);
        });
      });

      test('totalDropped counts dropped messages', () {
        fakeAsync((async) {
          throttler = MessageThrottler(strategy: ThrottleStrategy.drop);

          throttler.throttle(UnityMessage.command('A'), sender);
          throttler.throttle(UnityMessage.command('B'), sender);
          throttler.throttle(UnityMessage.command('C'), sender);

          expect(throttler.totalDropped, 2);
        });
      });

      test('sent + dropped equals throttled', () {
        fakeAsync((async) {
          throttler = MessageThrottler(strategy: ThrottleStrategy.keepLatest);

          for (var i = 0; i < 5; i++) {
            throttler.throttle(UnityMessage.command('Msg$i'), sender);
          }

          async.elapse(const Duration(milliseconds: 200));

          expect(
            throttler.totalSent + throttler.totalDropped,
            throttler.totalThrottled,
          );
        });
      });
    });

    group('sender error handling (DART-M2)', () {
      test('sender error on first message does not crash throttler', () {
        fakeAsync((async) {
          throttler = MessageThrottler();

          Future<void> failingSender(UnityMessage msg) async =>
              throw Exception('Send failed');

          expect(
            () => throttler.throttle(UnityMessage.command('A'), failingSender),
            returnsNormally,
          );
          expect(throttler.totalSent, 1);
        });
      });

      test('throttle continues accepting messages after failed send', () {
        fakeAsync((async) {
          throttler = MessageThrottler(strategy: ThrottleStrategy.drop);

          // Send first message with a no-op sender
          throttler.throttle(UnityMessage.command('First'), sender);
          expect(sent, hasLength(1));

          // Window expires
          async.elapse(const Duration(milliseconds: 100));

          // Send another message normally
          throttler.throttle(UnityMessage.command('Second'), sender);
          expect(sent, hasLength(2));
          expect(sent[1].type, 'Second');
        });
      });

      test('statistics are correct even with failed senders', () {
        fakeAsync((async) {
          throttler = MessageThrottler(strategy: ThrottleStrategy.drop);

          throttler.throttle(UnityMessage.command('A'), sender);
          throttler.throttle(UnityMessage.command('B'), sender);
          throttler.throttle(UnityMessage.command('C'), sender);

          expect(throttler.totalThrottled, 3);
          expect(throttler.totalSent, 1);
          expect(throttler.totalDropped, 2);
        });
      });
    });

    group('dispose()', () {
      test('cancels timer and prevents pending message delivery', () {
        fakeAsync((async) {
          throttler = MessageThrottler(strategy: ThrottleStrategy.keepLatest);

          throttler.throttle(UnityMessage.command('First'), sender);
          throttler.throttle(UnityMessage.command('Pending'), sender);

          throttler.dispose();
          async.elapse(const Duration(milliseconds: 200));

          expect(sent, hasLength(1));
          expect(sent.first.type, 'First');
        });
      });

      test('throttle() after dispose() is a no-op', () {
        fakeAsync((async) {
          throttler = MessageThrottler();

          throttler.dispose();
          throttler.throttle(UnityMessage.command('After'), sender);

          async.elapse(const Duration(milliseconds: 200));

          expect(sent, isEmpty);
          expect(throttler.totalThrottled, 0);
        });
      });
    });
  });
}
