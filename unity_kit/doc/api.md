# unity_kit API Reference

## Bridge & Messaging

### UnityBridge

```dart
abstract class UnityBridge {
  UnityLifecycleState get currentState;
  bool get isReady;

  // Streams
  Stream<UnityMessage> get messageStream;
  Stream<UnityPerformanceStats> get performanceStream;  // 2.0.0
  Stream<UnityEvent> get eventStream;
  Stream<SceneInfo> get sceneStream;
  Stream<UnityLifecycleState> get lifecycleStream;

  // Sending (JSON)
  Future<void> send(UnityMessage message);
  Future<void> sendWhenReady(UnityMessage message);

  // Sending (binary, 2.0.0)
  Future<void> sendBinary(UnityMessage message);
  Future<void> sendBinaryWhenReady(UnityMessage message);

  // Lifecycle
  Future<void> initialize();
  Future<void> pause();
  Future<void> resume();
  Future<void> unload();
  Future<void> dispose();
}
```

### UnityBinaryCodec (2.0.0)

Compact, length-prefixed binary frame for `UnityMessage`. Symmetric with the
Unity-side `UnityKitBinaryCodec`.

```dart
Uint8List bytes = UnityBinaryCodec.encode(UnityMessage.command('Move', {'x': 1}));
UnityMessage msg = UnityBinaryCodec.decode(bytes);
bool ok           = UnityBinaryCodec.isBinaryFrame(bytes);
```

`UnityBinaryWriter` / `UnityBinaryReader` hand-pack typed payloads:
`writeInt32`, `writeInt64`, `writeFloat64`, `writeBool`, `writeString`
(and matching `read*`).

### UnityPerformanceStats (2.0.0)

```dart
class UnityPerformanceStats {
  final double fps;
  final double frameTimeMs;
  final double usedMemoryMb;
  final int drawCalls;
  final int triangles;
}
```

Emitted on `bridge.performanceStream` from the Unity-side
`UnityKitPerformanceMonitor`.

### UnityConfig / UnityArMode (2.0.0 AR)

```dart
const UnityConfig({ ..., UnityArMode arMode = UnityArMode.none });

// Factory: transparent overlay AR by default.
UnityConfig.ar({ String sceneName = 'MainScene', UnityArMode mode = UnityArMode.overlay });

enum UnityArMode { none, passthrough, overlay }
```

`UnityConfig.toCreationParams()` is the canonical Dart → native map (carries
`sceneName` and `arMode`).

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
