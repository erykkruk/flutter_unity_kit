import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/utils/constants.dart';

void main() {
  group('UnityMethods', () {
    test('contains all Flutter to Unity method names', () {
      expect(UnityMethods.loadScene, 'LoadScene');
      expect(UnityMethods.unloadScene, 'UnloadScene');
      expect(UnityMethods.setConfig, 'SetConfig');
      expect(UnityMethods.triggerAction, 'TriggerAction');
      expect(UnityMethods.queryState, 'QueryState');
      expect(UnityMethods.receiveMessage, 'ReceiveMessage');
      expect(UnityMethods.pause, 'Pause');
      expect(UnityMethods.resume, 'Resume');
      expect(UnityMethods.quit, 'Quit');
    });
  });

  group('UnitySignals', () {
    test('contains all Unity to Flutter signal types', () {
      expect(UnitySignals.ready, 'ready');
      expect(UnitySignals.sceneLoaded, 'scene_loaded');
      expect(UnitySignals.sceneUnloaded, 'scene_unloaded');
      expect(UnitySignals.stateUpdate, 'state_update');
      expect(UnitySignals.error, 'error');
      expect(UnitySignals.paused, 'paused');
      expect(UnitySignals.resumed, 'resumed');
      expect(UnitySignals.destroyed, 'destroyed');
    });
  });

  group('UnityGameObjects', () {
    test('has default FlutterBridge name', () {
      expect(UnityGameObjects.flutterBridge, 'FlutterBridge');
    });
  });

  group('ChannelNames', () {
    test('generates method channel name with viewId', () {
      expect(ChannelNames.methodChannel(0), 'com.unity_kit/unity_view_0');
      expect(ChannelNames.methodChannel(1), 'com.unity_kit/unity_view_1');
      expect(ChannelNames.methodChannel(42), 'com.unity_kit/unity_view_42');
    });

    test('has event channel constant', () {
      expect(ChannelNames.eventChannel, 'com.unity_kit/unity_events');
    });
  });
}
