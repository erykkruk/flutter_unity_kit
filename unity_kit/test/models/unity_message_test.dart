import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/models/unity_message.dart';

void main() {
  group('UnityMessage', () {
    test('creates with required fields', () {
      const msg = UnityMessage(type: 'test');

      expect(msg.type, 'test');
      expect(msg.data, isNull);
      expect(msg.gameObject, 'FlutterBridge');
      expect(msg.method, 'ReceiveMessage');
    });

    test('creates with all fields', () {
      const msg = UnityMessage(
        type: 'action',
        data: {'key': 'value'},
        gameObject: 'Player',
        method: 'DoSomething',
      );

      expect(msg.type, 'action');
      expect(msg.data, {'key': 'value'});
      expect(msg.gameObject, 'Player');
      expect(msg.method, 'DoSomething');
    });

    group('command factory', () {
      test('creates command without data', () {
        final msg = UnityMessage.command('Init');

        expect(msg.type, 'Init');
        expect(msg.data, isNull);
        expect(msg.gameObject, 'FlutterBridge');
      });

      test('creates command with data', () {
        final msg = UnityMessage.command('Load', {'level': 1});

        expect(msg.type, 'Load');
        expect(msg.data, {'level': 1});
      });
    });

    group('to factory', () {
      test('creates targeted message', () {
        final msg = UnityMessage.to('Player', 'Move');

        expect(msg.gameObject, 'Player');
        expect(msg.method, 'Move');
        expect(msg.type, 'Move');
      });

      test('creates targeted message with data', () {
        final msg = UnityMessage.to('Player', 'Move', {'x': 10});

        expect(msg.data, {'x': 10});
      });
    });

    group('fromJson factory', () {
      test('parses JSON with type only', () {
        final msg = UnityMessage.fromJson('{"type":"ready"}');

        expect(msg.type, 'ready');
        expect(msg.data, isNull);
      });

      test('parses JSON with type and data', () {
        final msg = UnityMessage.fromJson(
          '{"type":"score","data":{"value":100}}',
        );

        expect(msg.type, 'score');
        expect(msg.data, {'value': 100});
      });

      test('throws on invalid JSON', () {
        expect(
          () => UnityMessage.fromJson('not json'),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws on missing type field', () {
        expect(
          () => UnityMessage.fromJson('{"data":"test"}'),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('toJson', () {
      test('serializes type only', () {
        const msg = UnityMessage(type: 'test');
        final json = msg.toJson();

        expect(json, '{"type":"test"}');
      });

      test('serializes type with data', () {
        const msg = UnityMessage(type: 'test', data: {'key': 'val'});
        final json = msg.toJson();

        expect(json, contains('"type":"test"'));
        expect(json, contains('"data"'));
        expect(json, contains('"key":"val"'));
      });
    });

    test('toString returns readable format', () {
      const msg = UnityMessage(type: 'test', data: {'a': 1});

      expect(msg.toString(), contains('UnityMessage'));
      expect(msg.toString(), contains('test'));
    });
  });
}
