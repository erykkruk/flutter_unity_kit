import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/platform/unity_kit_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UnityKitMethodChannel', () {
    late UnityKitMethodChannel platform;
    late List<MethodCall> log;

    setUp(() {
      platform = UnityKitMethodChannel();
      log = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.unity_kit/unity_view_0'),
        (call) async {
          log.add(call);
          switch (call.method) {
            case 'unity#isReady':
              return true;
            case 'unity#isLoaded':
              return true;
            case 'unity#isPaused':
              return false;
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.unity_kit/unity_view_0'),
        null,
      );
    });

    test('viewType returns correct identifier', () {
      expect(platform.viewType, 'com.unity_kit/unity_view');
    });

    test('isReady invokes correct method', () async {
      final result = await platform.isReady();
      expect(result, isTrue);
      expect(log.last.method, 'unity#isReady');
    });

    test('isLoaded invokes correct method', () async {
      final result = await platform.isLoaded();
      expect(result, isTrue);
      expect(log.last.method, 'unity#isLoaded');
    });

    test('isPaused invokes correct method', () async {
      final result = await platform.isPaused();
      expect(result, isFalse);
      expect(log.last.method, 'unity#isPaused');
    });

    test('postMessage sends correct arguments', () async {
      await platform.postMessage('FlutterBridge', 'ReceiveMessage', '{}');

      expect(log.last.method, 'unity#postMessage');
      expect(log.last.arguments, {
        'gameObject': 'FlutterBridge',
        'methodName': 'ReceiveMessage',
        'message': '{}',
      });
    });

    test('pause invokes pausePlayer', () async {
      await platform.pause();
      expect(log.last.method, 'unity#pausePlayer');
    });

    test('resume invokes resumePlayer', () async {
      await platform.resume();
      expect(log.last.method, 'unity#resumePlayer');
    });

    test('unload invokes unloadPlayer', () async {
      await platform.unload();
      expect(log.last.method, 'unity#unloadPlayer');
    });

    test('quit invokes quitPlayer', () async {
      await platform.quit();
      expect(log.last.method, 'unity#quitPlayer');
    });

    test('initialize ensures channel exists without invoking native method',
        () async {
      await platform.initialize(earlyInit: true);
      // initialize() only creates the MethodChannel for receiving events;
      // the native side auto-initializes when the PlatformView is created.
      // No method call is sent, so log should be empty.
      expect(log, isEmpty);
    });

    test('createUnityPlayer sends config', () async {
      await platform.createUnityPlayer(0, {'fullscreen': true});
      expect(log.last.method, 'unity#createPlayer');
      expect(log.last.arguments, {'fullscreen': true});
    });

    test('dispose invokes native dispose before clearing handler (DART-M3)',
        () async {
      // Access channel to register it
      await platform.isReady();

      await platform.dispose(0);

      // Verify dispose was called on native side
      expect(log.last.method, 'unity#dispose');
    });

    test('dispose removes channel from map', () async {
      // Access channel to register it
      await platform.isReady();

      await platform.dispose(0);

      // The channel should be removed; creating a new one should work
      final newPlatform = UnityKitMethodChannel();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.unity_kit/unity_view_0'),
        (call) async {
          log.add(call);
          if (call.method == 'unity#isReady') return true;
          return null;
        },
      );

      final result = await newPlatform.isReady();
      expect(result, isTrue);
    });

    test('events stream emits on platform call', () async {
      final events = <Map<String, dynamic>>[];
      final sub = platform.events.listen(events.add);

      // Trigger a platform call by accessing the channel
      await platform.isReady();

      // Simulate native calling back
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const codec = StandardMethodCodec();
      final data = codec.encodeMethodCall(
        const MethodCall('onUnityMessage', {'message': 'hello'}),
      );
      await messenger.handlePlatformMessage(
        'com.unity_kit/unity_view_0',
        data,
        (ByteData? reply) {},
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, isNotEmpty);
      expect(events.last['event'], 'onUnityMessage');
      expect(events.last['message'], 'hello');

      await sub.cancel();
    });
  });
}
