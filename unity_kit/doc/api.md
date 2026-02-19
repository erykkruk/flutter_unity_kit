# unity_kit API Reference

## Streaming Module

### UnityAssetLoader (abstract)

Abstract interface for loading assets on the Unity side.

```dart
abstract class UnityAssetLoader {
  String get targetName;
  UnityMessage setCachePathMessage(String cachePath);
  UnityMessage loadAssetMessage({required String key, required String callbackId});
  UnityMessage loadSceneMessage({required String sceneName, required String callbackId, required String loadMode});
  UnityMessage unloadAssetMessage(String key);

  // Convenience methods (use bridge.sendWhenReady internally)
  Future<void> setCachePath(UnityBridge bridge, String cachePath);
  Future<void> loadAsset(UnityBridge bridge, {required String key, required String callbackId});
  Future<void> loadScene(UnityBridge bridge, {required String sceneName, required String callbackId, required String loadMode});
  Future<void> unloadAsset(UnityBridge bridge, String key);
}
```

### UnityAddressablesLoader

Sends messages to `FlutterAddressablesManager` (C#). Uses Unity Addressables API.

| Property | Value |
|----------|-------|
| `targetName` | `FlutterAddressablesManager` |
| Load method | `LoadAsset` with `key` |
| Scene method | `LoadScene` with `sceneName` |
| Unload method | `UnloadAsset` with `key` |

```dart
const loader = UnityAddressablesLoader(); // default
```

### UnityBundleLoader

Sends messages to `FlutterAssetBundleManager` (C#). Uses raw `AssetBundle.LoadFromFileAsync`.

| Property | Value |
|----------|-------|
| `targetName` | `FlutterAssetBundleManager` |
| Load method | `LoadBundle` with `bundleName` |
| Scene method | `LoadScene` with `bundleName` |
| Unload method | `UnloadBundle` with `bundleName` |

```dart
const loader = UnityBundleLoader();
```

### StreamingController

Orchestrates manifest fetching, downloading, caching, and Unity communication.

```dart
StreamingController({
  required UnityBridge bridge,
  required String manifestUrl,
  UnityAssetLoader? assetLoader,  // defaults to UnityAddressablesLoader
  http.Client? httpClient,
  CacheManager? cacheManager,
})
```

| Property/Method | Description |
|-----------------|-------------|
| `assetLoader` | The loader strategy in use |
| `state` | Current `StreamingState` |
| `downloadProgress` | Stream of `DownloadProgress` |
| `errors` | Stream of `StreamingError` |
| `stateChanges` | Stream of `StreamingState` |
| `initialize()` | Fetch manifest, init cache, notify Unity |
| `preloadContent({bundles, strategy})` | Download base bundles |
| `loadBundle(name)` | Download + tell Unity to load |
| `loadScene(name, {loadMode})` | Download + tell Unity to load scene |
| `getCachedBundles()` | List cached bundle names |
| `isBundleCached(name)` | Check if bundle is cached |
| `getCacheSize()` | Total cache size in bytes |
| `clearCache()` | Delete all cached content |
| `dispose()` | Release all resources |

### ContentDownloader

HTTP downloader with retries, progress tracking, and cancellation.

### CacheManager

Local disk cache with SHA-256 integrity verification.

### Models

| Model | Description |
|-------|-------------|
| `ContentManifest` | Versioned manifest with bundle list |
| `ContentBundle` | Bundle descriptor (name, url, size, sha256) |
| `DownloadProgress` | Download tracking with speed/ETA |
| `DownloadState` | Enum: queued, downloading, completed, cached, failed, cancelled |
| `DownloadStrategy` | Enum: wifiOnly, wifiOrCellular, any, manual |
| `StreamingState` | Enum: uninitialized, initializing, ready, downloading, error |
| `StreamingError` | Typed error with cause |
