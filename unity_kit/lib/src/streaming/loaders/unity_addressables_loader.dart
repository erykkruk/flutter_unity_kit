import '../../models/unity_message.dart';
import '../unity_asset_loader.dart';

/// Unity GameObject name for the C# Addressables manager.
const String _kTargetName = 'FlutterAddressablesManager';

/// Asset loader that communicates with Unity Addressables.
///
/// Sends messages to the `FlutterAddressablesManager` C# MonoBehaviour
/// which loads assets via `Addressables.LoadAssetAsync` and scenes via
/// `Addressables.LoadSceneAsync`.
///
/// This is the default loader used by [StreamingController] when no
/// explicit `assetLoader` is provided.
///
/// Example:
/// ```dart
/// const loader = UnityAddressablesLoader();
/// final message = loader.loadAssetMessage(
///   key: 'characters',
///   callbackId: 'load_characters',
/// );
/// ```
class UnityAddressablesLoader extends UnityAssetLoader {
  /// Creates a [UnityAddressablesLoader].
  const UnityAddressablesLoader();

  @override
  String get targetName => _kTargetName;

  @override
  UnityMessage setCachePathMessage(String cachePath) {
    return UnityMessage.to(
      _kTargetName,
      'SetCachePath',
      {'path': cachePath},
    );
  }

  @override
  UnityMessage loadAssetMessage({
    required String key,
    required String callbackId,
  }) {
    return UnityMessage.to(
      _kTargetName,
      'LoadAsset',
      {
        'key': key,
        'callbackId': callbackId,
      },
    );
  }

  @override
  UnityMessage loadSceneMessage({
    required String sceneName,
    required String callbackId,
    required String loadMode,
  }) {
    return UnityMessage.to(
      _kTargetName,
      'LoadScene',
      {
        'sceneName': sceneName,
        'callbackId': callbackId,
        'loadMode': loadMode,
      },
    );
  }

  @override
  UnityMessage unloadAssetMessage(String key) {
    return UnityMessage.to(
      _kTargetName,
      'UnloadAsset',
      {'key': key},
    );
  }
}
