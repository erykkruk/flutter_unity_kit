# Asset Streaming Guide

## Overview

`unity_kit` supports two asset loading strategies for Unity:

| Strategy | Class | C# Manager | Unity Package Required |
|----------|-------|-------------|----------------------|
| **Addressables** (default) | `UnityAddressablesLoader` | `FlutterAddressablesManager` | `com.unity.addressables` |
| **Raw AssetBundles** | `UnityBundleLoader` | `FlutterAssetBundleManager` | None (built-in) |

Both share the same download/cache infrastructure (`ContentDownloader`, `CacheManager`) and manifest format (`ContentManifest`).

## Dart Usage

### Option A: Addressables (default)

```dart
final controller = StreamingController(
  bridge: bridge,
  manifestUrl: 'https://cdn.example.com/manifest.json',
);

await controller.initialize();
await controller.loadBundle('characters');
await controller.loadScene('BattleArena', loadMode: 'Additive');
```

### Option B: Raw AssetBundles

```dart
final controller = StreamingController(
  bridge: bridge,
  manifestUrl: 'https://cdn.example.com/manifest.json',
  assetLoader: const UnityBundleLoader(),
);

await controller.initialize();
await controller.loadBundle('characters');
await controller.loadScene('BattleArena', loadMode: 'Additive');
```

### Common API

Both strategies expose the same `StreamingController` API:

```dart
// Progress tracking
controller.downloadProgress.listen((progress) {
  print('${progress.bundleName}: ${progress.percentageString}');
  print('Speed: ${progress.speedString}');
  print('ETA: ${progress.etaString}');
});

// Error handling
controller.errors.listen((error) {
  print('Error: ${error.type} - ${error.message}');
});

// Preload base bundles
await controller.preloadContent(strategy: DownloadStrategy.wifiOnly);

// Cache management
final cached = controller.getCachedBundles();
final size = controller.getCacheSize();
await controller.clearCache();
```

## Unity Setup

### Option A: Addressables

1. Install the Addressables package:
   - Unity Package Manager > `com.unity.addressables`

2. Add scripting define symbol:
   - Project Settings > Player > Scripting Define Symbols > Add `ADDRESSABLES_INSTALLED`

3. Configure Addressable Groups:
   - Base content: Local Build + Local Load paths
   - Streaming content: Remote Build + Remote Load paths

4. Build content:
   - Menu: **Flutter > Build Addressables**
   - This generates `content_manifest.json` in the remote build folder

5. Upload to CDN:
   - Upload all `.bundle` files and `content_manifest.json`

6. Add `FlutterAddressablesManager` to your Unity scene:
   - Create an empty GameObject
   - Attach the `FlutterAddressablesManager` component
   - It auto-registers with `MessageRouter`

### Option B: Raw AssetBundles

1. Mark assets with AssetBundle labels:
   - Select assets in the Inspector
   - Set the AssetBundle label at the bottom

2. Build bundles:
   - Menu: **Flutter > Build AssetBundles**
   - Output: `Builds/AssetBundles/` with `content_manifest.json`

3. Update manifest URLs:
   - Replace `{BASE_URL}` placeholder in `content_manifest.json` with your CDN URL

4. Upload to CDN:
   - Upload all bundle files and `content_manifest.json`

5. Add `FlutterAssetBundleManager` to your Unity scene:
   - Create an empty GameObject
   - Attach the `FlutterAssetBundleManager` component
   - It auto-registers with `MessageRouter`

## Manifest Format

Both strategies use the same JSON format:

```json
{
  "version": "1.0.0",
  "baseUrl": "https://cdn.example.com/bundles",
  "bundles": [
    {
      "name": "characters",
      "url": "https://cdn.example.com/bundles/characters",
      "sizeBytes": 5242880,
      "sha256": "a1b2c3...",
      "isBase": false,
      "dependencies": ["core"],
      "group": "streaming"
    }
  ],
  "buildTime": "2024-01-15T10:30:00Z",
  "platform": "Android"
}
```

## Custom Loader

Create a custom loader by extending `UnityAssetLoader`:

```dart
class MyCustomLoader extends UnityAssetLoader {
  const MyCustomLoader();

  @override
  String get targetName => 'MyCustomManager';

  @override
  UnityMessage setCachePathMessage(String cachePath) =>
    UnityMessage.to(targetName, 'SetCachePath', {'path': cachePath});

  @override
  UnityMessage loadAssetMessage({required String key, required String callbackId}) =>
    UnityMessage.to(targetName, 'Load', {'key': key, 'callbackId': callbackId});

  // ... implement remaining methods
}
```

## Architecture

```
StreamingController (orchestrator)
├── CacheManager (shared — local disk cache with SHA-256)
├── ContentDownloader (shared — HTTP + retry + progress)
└── UnityAssetLoader (swappable strategy)
    ├── UnityAddressablesLoader → FlutterAddressablesManager.cs
    └── UnityBundleLoader       → FlutterAssetBundleManager.cs
```
