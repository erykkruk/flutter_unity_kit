import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/streaming/loaders/unity_bundle_loader.dart';

void main() {
  const loader = UnityBundleLoader();

  group('UnityBundleLoader', () {
    test('can be created as const', () {
      const a = UnityBundleLoader();
      const b = UnityBundleLoader();
      expect(identical(a, b), isTrue);
    });

    test('targetName is FlutterAssetBundleManager', () {
      expect(loader.targetName, 'FlutterAssetBundleManager');
    });

    group('setCachePathMessage', () {
      test('creates message with correct target and method', () {
        final message = loader.setCachePathMessage('/data/cache');

        expect(message.gameObject, 'FlutterAssetBundleManager');
        expect(message.method, 'SetCachePath');
        expect(message.data, {'path': '/data/cache'});
      });

      test('preserves empty path', () {
        final message = loader.setCachePathMessage('');
        expect(message.data!['path'], '');
      });

      test('preserves path with spaces and unicode', () {
        final message = loader.setCachePathMessage('/data/user 0/cache/日本語');
        expect(message.data!['path'], '/data/user 0/cache/日本語');
      });
    });

    group('loadAssetMessage', () {
      test('creates LoadBundle message with bundleName and callbackId', () {
        final message = loader.loadAssetMessage(
          key: 'characters',
          callbackId: 'load_characters',
        );

        expect(message.gameObject, 'FlutterAssetBundleManager');
        expect(message.method, 'LoadBundle');
        expect(message.data, {
          'bundleName': 'characters',
          'callbackId': 'load_characters',
        });
      });

      test('uses bundleName instead of key in payload', () {
        final message = loader.loadAssetMessage(
          key: 'weapons',
          callbackId: 'load_weapons',
        );

        expect(message.data!.containsKey('bundleName'), isTrue);
        expect(message.data!.containsKey('key'), isFalse);
      });

      test('maps key parameter to bundleName field', () {
        final message = loader.loadAssetMessage(
          key: 'my_custom_key',
          callbackId: 'cb',
        );

        expect(message.data!['bundleName'], 'my_custom_key');
      });

      test('uses LoadBundle method (not LoadAsset)', () {
        final message = loader.loadAssetMessage(
          key: 'test',
          callbackId: 'cb',
        );

        expect(message.method, 'LoadBundle');
      });

      test('data contains exactly two entries', () {
        final message = loader.loadAssetMessage(
          key: 'k',
          callbackId: 'c',
        );

        expect(message.data!.length, 2);
      });
    });

    group('loadSceneMessage', () {
      test('creates LoadScene message with bundleName and loadMode', () {
        final message = loader.loadSceneMessage(
          sceneName: 'BattleArena',
          callbackId: 'scene_BattleArena',
          loadMode: 'Additive',
        );

        expect(message.gameObject, 'FlutterAssetBundleManager');
        expect(message.method, 'LoadScene');
        expect(message.data, {
          'bundleName': 'BattleArena',
          'callbackId': 'scene_BattleArena',
          'loadMode': 'Additive',
        });
      });

      test('uses bundleName instead of sceneName in payload', () {
        final message = loader.loadSceneMessage(
          sceneName: 'MainMenu',
          callbackId: 'scene_MainMenu',
          loadMode: 'Single',
        );

        expect(message.data!.containsKey('bundleName'), isTrue);
        expect(message.data!.containsKey('sceneName'), isFalse);
      });

      test('maps sceneName parameter to bundleName field', () {
        final message = loader.loadSceneMessage(
          sceneName: 'my_scene',
          callbackId: 'cb',
          loadMode: 'Single',
        );

        expect(message.data!['bundleName'], 'my_scene');
      });

      test('passes Single loadMode correctly', () {
        final message = loader.loadSceneMessage(
          sceneName: 'MainMenu',
          callbackId: 'scene_MainMenu',
          loadMode: 'Single',
        );

        expect(message.data!['loadMode'], 'Single');
      });

      test('passes Additive loadMode correctly', () {
        final message = loader.loadSceneMessage(
          sceneName: 'HUD',
          callbackId: 'scene_HUD',
          loadMode: 'Additive',
        );

        expect(message.data!['loadMode'], 'Additive');
      });

      test('data contains exactly three entries', () {
        final message = loader.loadSceneMessage(
          sceneName: 's',
          callbackId: 'c',
          loadMode: 'Single',
        );

        expect(message.data!.length, 3);
      });
    });

    group('unloadAssetMessage', () {
      test('creates UnloadBundle message with bundleName', () {
        final message = loader.unloadAssetMessage('characters');

        expect(message.gameObject, 'FlutterAssetBundleManager');
        expect(message.method, 'UnloadBundle');
        expect(message.data, {'bundleName': 'characters'});
      });

      test('uses UnloadBundle method (not UnloadAsset)', () {
        final message = loader.unloadAssetMessage('weapons');
        expect(message.method, 'UnloadBundle');
      });

      test('uses bundleName instead of key in payload', () {
        final message = loader.unloadAssetMessage('weapons');
        expect(message.data!.containsKey('bundleName'), isTrue);
        expect(message.data!.containsKey('key'), isFalse);
      });

      test('maps key parameter to bundleName field', () {
        final message = loader.unloadAssetMessage('my_bundle');
        expect(message.data!['bundleName'], 'my_bundle');
      });
    });

    group('message type field', () {
      test('setCachePathMessage type matches method', () {
        final message = loader.setCachePathMessage('/path');
        expect(message.type, 'SetCachePath');
      });

      test('loadAssetMessage type is LoadBundle', () {
        final message = loader.loadAssetMessage(key: 'k', callbackId: 'c');
        expect(message.type, 'LoadBundle');
      });

      test('loadSceneMessage type is LoadScene', () {
        final message = loader.loadSceneMessage(
          sceneName: 's',
          callbackId: 'c',
          loadMode: 'Single',
        );
        expect(message.type, 'LoadScene');
      });

      test('unloadAssetMessage type is UnloadBundle', () {
        final message = loader.unloadAssetMessage('k');
        expect(message.type, 'UnloadBundle');
      });
    });

    group('payload key differences from Addressables', () {
      test('loadAsset uses bundleName where Addressables uses key', () {
        final message = loader.loadAssetMessage(
          key: 'test',
          callbackId: 'cb',
        );

        // BundleLoader sends bundleName, not key.
        expect(message.data!.keys, containsAll(['bundleName', 'callbackId']));
        expect(message.data!.keys, isNot(contains('key')));
      });

      test('loadScene uses bundleName where Addressables uses sceneName', () {
        final message = loader.loadSceneMessage(
          sceneName: 'test',
          callbackId: 'cb',
          loadMode: 'Single',
        );

        expect(
          message.data!.keys,
          containsAll(['bundleName', 'callbackId', 'loadMode']),
        );
        expect(message.data!.keys, isNot(contains('sceneName')));
      });

      test('unload uses bundleName where Addressables uses key', () {
        final message = loader.unloadAssetMessage('test');

        expect(message.data!.keys, contains('bundleName'));
        expect(message.data!.keys, isNot(contains('key')));
      });
    });
  });
}
