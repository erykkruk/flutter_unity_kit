import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/bridge/unity_binary_codec.dart';
import 'package:unity_kit/src/bridge/unity_bridge.dart';
import 'package:unity_kit/src/models/models.dart';
import 'package:unity_kit/src/platform/unity_kit_platform.dart';

/// Minimal fake platform that records sends and emits native events.
class _FakePlatform extends UnityKitPlatform {
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();
  final List<Map<String, String>> sent = [];

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;

  @override
  String get viewType => 'test/unity_view';

  @override
  Future<void> initialize({bool earlyInit = false}) async {}

  @override
  Future<bool> isReady() async => true;

  @override
  Future<bool> isLoaded() async => true;

  @override
  Future<bool> isPaused() async => false;

  @override
  Future<void> postMessage(
    String gameObject,
    String methodName,
    String message,
  ) async {
    sent.add({
      'gameObject': gameObject,
      'methodName': methodName,
      'message': message,
    });
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> unload() async {}

  @override
  Future<void> quit() async {}

  @override
  Future<void> dispose(int viewId) async {}

  @override
  void registerViewChannel(int viewId) {}

  @override
  Future<void> createUnityPlayer(
      int viewId, Map<String, dynamic> config) async {}

  void emit(Map<String, dynamic> event) => _events.add(event);

  Future<void> close() => _events.close();
}

void main() {
  late _FakePlatform platform;
  late UnityBridgeImpl bridge;

  setUp(() async {
    platform = _FakePlatform();
    bridge = UnityBridgeImpl(platform: platform);
    await bridge.initialize();
    platform.emit({'event': 'onUnityCreated'});
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() async {
    await bridge.dispose();
    await platform.close();
  });

  test('sendBinary posts a base64 ReceiveBinary frame', () async {
    await bridge.sendBinary(UnityMessage.command('Move', {'x': 1}));

    expect(platform.sent, hasLength(1));
    final sent = platform.sent.single;
    expect(sent['methodName'], 'ReceiveBinary');
    expect(sent['gameObject'], 'FlutterBridge');

    final bytes = Uint8List.fromList(base64Decode(sent['message']!));
    final decoded = UnityBinaryCodec.decode(bytes);
    expect(decoded.type, 'Move');
    expect(decoded.data, {'x': 1});
  });

  test('performance messages route to performanceStream only', () async {
    final perf = bridge.performanceStream.first;
    final messages = <UnityMessage>[];
    final sub = bridge.messageStream.listen(messages.add);

    platform.emit({
      'event': 'onUnityMessage',
      'data': '{"type":"__perf","data":{"fps":60,"drawCalls":12}}',
    });

    final stats = await perf;
    expect(stats.fps, 60);
    expect(stats.drawCalls, 12);

    await Future<void>.delayed(Duration.zero);
    expect(messages, isEmpty);

    await sub.cancel();
  });

  test('regular messages still reach messageStream', () async {
    final next = bridge.messageStream.first;

    platform.emit({
      'event': 'onUnityMessage',
      'data': '{"type":"score","data":{"value":10}}',
    });

    final message = await next;
    expect(message.type, 'score');
    expect(message.data, {'value': 10});
  });

  test('sendBinaryWhenReady queues before ready and flushes after', () async {
    final freshPlatform = _FakePlatform();
    final freshBridge = UnityBridgeImpl(platform: freshPlatform);
    await freshBridge.initialize();

    // Not ready yet: the binary frame must be queued, not sent.
    await freshBridge.sendBinaryWhenReady(UnityMessage.command('Queued'));
    expect(freshPlatform.sent, isEmpty);

    // Becoming ready flushes the queue.
    freshPlatform.emit({'event': 'onUnityCreated'});
    await Future<void>.delayed(Duration.zero);

    expect(freshPlatform.sent, hasLength(1));
    expect(freshPlatform.sent.single['methodName'], 'ReceiveBinary');

    final bytes =
        Uint8List.fromList(base64Decode(freshPlatform.sent.single['message']!));
    expect(UnityBinaryCodec.decode(bytes).type, 'Queued');

    await freshBridge.dispose();
    await freshPlatform.close();
  });
}
