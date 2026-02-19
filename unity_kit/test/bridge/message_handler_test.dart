import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/bridge/message_handler.dart';
import 'package:unity_kit/src/models/unity_message.dart';

void main() {
  late MessageHandler handler;

  setUp(() {
    handler = MessageHandler();
  });

  tearDown(() {
    handler.dispose();
  });

  group('MessageHandler', () {
    group('on() and handle()', () {
      test('registers handler and routes matching message to it', () {
        final received = <UnityMessage>[];
        handler.on('scene_loaded', received.add);

        const message =
            UnityMessage(type: 'scene_loaded', data: {'name': 'Level1'});
        handler.handle(message);

        expect(received, hasLength(1));
        expect(received.first.type, 'scene_loaded');
        expect(received.first.data, {'name': 'Level1'});
      });

      test('multiple handlers for same type all get called', () {
        final firstReceived = <UnityMessage>[];
        final secondReceived = <UnityMessage>[];
        handler.on('event', firstReceived.add);
        handler.on('event', secondReceived.add);

        const message = UnityMessage(type: 'event');
        handler.handle(message);

        expect(firstReceived, hasLength(1));
        expect(secondReceived, hasLength(1));
      });

      test('handle() with no registered handler does nothing', () {
        const message = UnityMessage(type: 'unknown_type');

        // Should not throw.
        expect(() => handler.handle(message), returnsNormally);
      });

      test('handlers for different types are independent', () {
        final sceneMessages = <UnityMessage>[];
        final errorMessages = <UnityMessage>[];
        handler.on('scene_loaded', sceneMessages.add);
        handler.on('error', errorMessages.add);

        const sceneMsg = UnityMessage(type: 'scene_loaded');
        const errorMsg = UnityMessage(type: 'error', data: {'code': 404});
        handler.handle(sceneMsg);
        handler.handle(errorMsg);

        expect(sceneMessages, hasLength(1));
        expect(sceneMessages.first.type, 'scene_loaded');
        expect(errorMessages, hasLength(1));
        expect(errorMessages.first.type, 'error');
        expect(errorMessages.first.data, {'code': 404});
      });

      test('same handler called multiple times for multiple messages', () {
        final received = <UnityMessage>[];
        handler.on('ping', received.add);

        handler.handle(const UnityMessage(type: 'ping', data: {'seq': 1}));
        handler.handle(const UnityMessage(type: 'ping', data: {'seq': 2}));
        handler.handle(const UnityMessage(type: 'ping', data: {'seq': 3}));

        expect(received, hasLength(3));
        expect(received[0].data, {'seq': 1});
        expect(received[1].data, {'seq': 2});
        expect(received[2].data, {'seq': 3});
      });
    });

    group('off()', () {
      test('removes specific handler', () {
        final received = <UnityMessage>[];
        void callback(UnityMessage msg) => received.add(msg);

        handler.on('event', callback);
        handler.off('event', callback);

        handler.handle(const UnityMessage(type: 'event'));

        expect(received, isEmpty);
      });

      test('other handlers for same type still work after off()', () {
        final firstReceived = <UnityMessage>[];
        final secondReceived = <UnityMessage>[];
        void firstCallback(UnityMessage msg) => firstReceived.add(msg);
        void secondCallback(UnityMessage msg) => secondReceived.add(msg);

        handler.on('event', firstCallback);
        handler.on('event', secondCallback);
        handler.off('event', firstCallback);

        handler.handle(const UnityMessage(type: 'event'));

        expect(firstReceived, isEmpty);
        expect(secondReceived, hasLength(1));
      });

      test('off() for non-existent type does nothing', () {
        void callback(UnityMessage msg) {}

        expect(() => handler.off('nonexistent', callback), returnsNormally);
      });

      test('off() for non-registered callback does nothing', () {
        void registeredCallback(UnityMessage msg) {}
        void otherCallback(UnityMessage msg) {}

        handler.on('event', registeredCallback);
        handler.off('event', otherCallback);

        final received = <UnityMessage>[];
        handler.on('event', received.add);
        handler.handle(const UnityMessage(type: 'event'));

        // registeredCallback is still active, plus the received.add one.
        expect(received, hasLength(1));
      });
    });

    group('offAll()', () {
      test('removes all handlers for a type', () {
        final firstReceived = <UnityMessage>[];
        final secondReceived = <UnityMessage>[];
        handler.on('event', firstReceived.add);
        handler.on('event', secondReceived.add);

        handler.offAll('event');

        handler.handle(const UnityMessage(type: 'event'));

        expect(firstReceived, isEmpty);
        expect(secondReceived, isEmpty);
      });

      test('offAll() does not affect other types', () {
        final eventReceived = <UnityMessage>[];
        final errorReceived = <UnityMessage>[];
        handler.on('event', eventReceived.add);
        handler.on('error', errorReceived.add);

        handler.offAll('event');

        handler.handle(const UnityMessage(type: 'event'));
        handler.handle(const UnityMessage(type: 'error'));

        expect(eventReceived, isEmpty);
        expect(errorReceived, hasLength(1));
      });

      test('offAll() for non-existent type does nothing', () {
        expect(() => handler.offAll('nonexistent'), returnsNormally);
      });
    });

    group('listenTo()', () {
      test('connects to stream and routes messages to handlers', () async {
        final controller = StreamController<UnityMessage>.broadcast();
        addTearDown(controller.close);

        final received = <UnityMessage>[];
        handler.on('stream_event', received.add);
        handler.listenTo(controller.stream);

        controller
            .add(const UnityMessage(type: 'stream_event', data: {'id': 1}));
        await Future<void>.delayed(Duration.zero);

        expect(received, hasLength(1));
        expect(received.first.data, {'id': 1});
      });

      test('routes multiple stream messages', () async {
        final controller = StreamController<UnityMessage>.broadcast();
        addTearDown(controller.close);

        final received = <UnityMessage>[];
        handler.on('msg', received.add);
        handler.listenTo(controller.stream);

        controller.add(const UnityMessage(type: 'msg', data: {'seq': 1}));
        controller.add(const UnityMessage(type: 'msg', data: {'seq': 2}));
        await Future<void>.delayed(Duration.zero);

        expect(received, hasLength(2));
      });

      test('can listen to multiple streams', () async {
        final controllerA = StreamController<UnityMessage>.broadcast();
        final controllerB = StreamController<UnityMessage>.broadcast();
        addTearDown(controllerA.close);
        addTearDown(controllerB.close);

        final received = <UnityMessage>[];
        handler.on('from_a', received.add);
        handler.on('from_b', received.add);
        handler.listenTo(controllerA.stream);
        handler.listenTo(controllerB.stream);

        controllerA.add(const UnityMessage(type: 'from_a'));
        controllerB.add(const UnityMessage(type: 'from_b'));
        await Future<void>.delayed(Duration.zero);

        expect(received, hasLength(2));
        expect(received.map((m) => m.type), containsAll(['from_a', 'from_b']));
      });
    });

    group('dispose()', () {
      test('cancels stream subscriptions', () async {
        final controller = StreamController<UnityMessage>.broadcast();
        addTearDown(controller.close);

        final received = <UnityMessage>[];
        handler.on('event', received.add);
        handler.listenTo(controller.stream);

        handler.dispose();

        controller.add(const UnityMessage(type: 'event'));
        await Future<void>.delayed(Duration.zero);

        expect(received, isEmpty);
      });

      test('clears all handlers', () {
        final received = <UnityMessage>[];
        handler.on('event', received.add);

        handler.dispose();

        handler.handle(const UnityMessage(type: 'event'));

        expect(received, isEmpty);
      });

      test('after dispose, handle() does nothing', () {
        final received = <UnityMessage>[];
        handler.on('type_a', received.add);
        handler.on('type_b', received.add);

        handler.dispose();

        handler.handle(const UnityMessage(type: 'type_a'));
        handler.handle(const UnityMessage(type: 'type_b'));

        expect(received, isEmpty);
      });
    });
  });
}
