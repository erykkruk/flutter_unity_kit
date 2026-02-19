import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/streaming/loaders/unity_addressables_loader.dart';

void main() {
  const loader = UnityAddressablesLoader();

  group('UnityAddressablesLoader', () {
    test('can be created as const', () {
      const a = UnityAddressablesLoader();
      const b = UnityAddressablesLoader();
      expect(identical(a, b), isTrue);
    });

    test('targetName is FlutterAddressablesManager', () {
      expect(loader.targetName, 'FlutterAddressablesManager');
    });

    group('setCachePathMessage', () {
      test('creates message with correct target and method', () {
        final message = loader.setCachePathMessage('/data/cache');

        expect(message.gameObject, 'FlutterAddressablesManager');
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
      test('creates LoadAsset message with key and callbackId', () {
        final message = loader.loadAssetMessage(
          key: 'characters',
          callbackId: 'load_characters',
        );

        expect(message.gameObject, 'FlutterAddressablesManager');
        expect(message.method, 'LoadAsset');
        expect(message.data, {
          'key': 'characters',
          'callbackId': 'load_characters',
        });
      });

      test('uses key field (not bundleName)', () {
        final message = loader.loadAssetMessage(
          key: 'weapons',
          callbackId: 'load_weapons',
        );

        expect(message.data!.containsKey('key'), isTrue);
        expect(message.data!.containsKey('bundleName'), isFalse);
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
      test('creates LoadScene message with sceneName and loadMode', () {
        final message = loader.loadSceneMessage(
          sceneName: 'BattleArena',
          callbackId: 'scene_BattleArena',
          loadMode: 'Additive',
        );

        expect(message.gameObject, 'FlutterAddressablesManager');
        expect(message.method, 'LoadScene');
        expect(message.data, {
          'sceneName': 'BattleArena',
          'callbackId': 'scene_BattleArena',
          'loadMode': 'Additive',
        });
      });

      test('uses sceneName field (not bundleName)', () {
        final message = loader.loadSceneMessage(
          sceneName: 'MainMenu',
          callbackId: 'scene_MainMenu',
          loadMode: 'Single',
        );

        expect(message.data!.containsKey('sceneName'), isTrue);
        expect(message.data!.containsKey('bundleName'), isFalse);
      });

      test('passes Single loadMode correctly', () {
        final message = loader.loadSceneMessage(
          sceneName: 'MainMenu',
          callbackId: 'scene_MainMenu',
          loadMode: 'Single',
        );

        expect(message.data!['loadMode'], 'Single');
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
      test('creates UnloadAsset message with key', () {
        final message = loader.unloadAssetMessage('characters');

        expect(message.gameObject, 'FlutterAddressablesManager');
        expect(message.method, 'UnloadAsset');
        expect(message.data, {'key': 'characters'});
      });

      test('uses UnloadAsset method (not UnloadBundle)', () {
        final message = loader.unloadAssetMessage('weapons');
        expect(message.method, 'UnloadAsset');
      });

      test('uses key field (not bundleName)', () {
        final message = loader.unloadAssetMessage('weapons');
        expect(message.data!.containsKey('key'), isTrue);
        expect(message.data!.containsKey('bundleName'), isFalse);
      });
    });

    group('message type field', () {
      test('setCachePathMessage type matches method', () {
        final message = loader.setCachePathMessage('/path');
        expect(message.type, 'SetCachePath');
      });

      test('loadAssetMessage type matches method', () {
        final message = loader.loadAssetMessage(key: 'k', callbackId: 'c');
        expect(message.type, 'LoadAsset');
      });

      test('loadSceneMessage type matches method', () {
        final message = loader.loadSceneMessage(
          sceneName: 's',
          callbackId: 'c',
          loadMode: 'Single',
        );
        expect(message.type, 'LoadScene');
      });

      test('unloadAssetMessage type matches method', () {
        final message = loader.unloadAssetMessage('k');
        expect(message.type, 'UnloadAsset');
      });
    });
  });
}
