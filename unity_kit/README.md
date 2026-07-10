# unity_kit

**Embed Unity 3D in Flutter with a typed, testable bridge** — send and receive
structured messages (JSON *or* a compact binary protocol), manage the player
lifecycle, stream live performance stats, drive AR Foundation sessions, and
stream Addressable assets. Runs on **Android, iOS, and web (WebGL)**, with
desktop scaffolding in place.

[![pub package](https://img.shields.io/pub/v/unity_kit.svg)](https://pub.dev/packages/unity_kit)
[![pub points](https://img.shields.io/pub/points/unity_kit)](https://pub.dev/packages/unity_kit/score)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Dart](https://img.shields.io/badge/Dart-3.4+-blue.svg)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-3.22+-blue.svg)](https://flutter.dev)
[![Unity](https://img.shields.io/badge/Unity-2022.3_LTS+-black.svg)](https://unity.com)

---

## 📚 Documentation

Full hosted documentation — a complete zero-to-running walkthrough, native setup guides, API reference and troubleshooting — lives at **[codigee.com/open-source/unity-kit](https://codigee.com/open-source/unity-kit)**.

| Guide | What's in it |
|-------|-------------|
| [Step-by-step walkthrough](https://codigee.com/open-source/unity-kit/step-by-step) | Zero-to-running: every file, path, and edit |
| [Unity export](https://codigee.com/open-source/unity-kit/unity-export) | Configure & export for Android, iOS, WebGL |
| [Android setup](https://codigee.com/open-source/unity-kit/android) | Native layer, Gradle, rendering |
| [iOS setup](https://codigee.com/open-source/unity-kit/ios) | UnityFramework embedding, Metal crash prevention |
| [Content loading](https://codigee.com/open-source/unity-kit/content-loading) | Scenes, prefabs, AssetBundles at runtime |
| [API reference](https://codigee.com/open-source/unity-kit/api) | Class signatures & parameters |
| [Asset streaming](https://codigee.com/open-source/unity-kit/asset-streaming) | CDN manifest + verified cache |
| [Architecture](https://codigee.com/open-source/unity-kit/architecture) | Bridge, lifecycle, streams |
| [FAQ](https://codigee.com/open-source/unity-kit/faq) | Troubleshooting common issues |

---

## What unity_kit offers

- **🎮 Embed Unity as a widget** — drop `UnityView` into your tree as a native
  platform view (Android, iOS, web) with gesture pass-through and a placeholder.
- **🔌 Typed two-way bridge** — `UnityBridge` with `UnityMessage`, broadcast
  streams for messages, scenes, lifecycle, and a `MessageHandler` for
  type-specific routing. No stringly-typed guesswork.
- **⚡ Binary protocol** — `sendBinary()` + `UnityBinaryCodec` for compact,
  high-frequency traffic; `UnityBinaryWriter`/`Reader` for hand-packed payloads.
- **📊 Performance monitoring** — `performanceStream` of `UnityPerformanceStats`
  (FPS, frame time, memory) fed by a Unity-side monitor.
- **🪟 AR Foundation** — `UnityConfig.ar()` + `UnityArMode` (passthrough /
  transparent overlay), wired through to the native host and Unity.
- **🧩 Attribute dispatch** — expose C# methods to Flutter with `[UnityKitMethod]`;
  no manual `switch` on the Unity side.
- **♻️ Robust lifecycle** — enforced state machine, readiness guard that queues
  messages until Unity is up, batching and throttling to tame native chatter.
- **📦 Asset streaming** — manifest-based downloads with SHA-256 integrity, disk
  caching, and Unity Addressables / AssetBundle loaders.
- **🛡️ Zero raw plugin deps in your face** — typed exceptions, transparent iOS
  rendering, three Android platform-view modes, and an Editor project validator.
- **✅ Tested** — 670+ Dart tests plus Unity EditMode tests, with a cross-language
  golden test locking the binary wire format on both sides.

---

## Features

| Feature | Description |
|---------|-------------|
| **Typed Bridge** | Abstract `UnityBridge` interface with `UnityMessage` for structured Flutter-Unity communication |
| **Binary Protocol** | Compact `UnityBinaryCodec` wire format + `bridge.sendBinary()` for high-frequency traffic, with `UnityBinaryWriter`/`UnityBinaryReader` for hand-packed payloads |
| **Performance Monitoring** | `bridge.performanceStream` of `UnityPerformanceStats` (FPS, frame time, memory) fed by the Unity-side `UnityKitPerformanceMonitor` |
| **AR Foundation** | `UnityConfig.ar()` + `UnityArMode` (passthrough / overlay) with a Unity-side `UnityKitArSession` bridge |
| **Attribute Dispatch** | Expose C# methods to Flutter with `[UnityKitMethod]` + `MessageRouter.RegisterMethods(...)` — no manual switch |
| **Lifecycle Management** | State machine with enforced transitions (`uninitialized` -> `ready` -> `paused` -> `resumed` -> `disposed`), plus the Unity-side `UnityKitGameManager` |
| **Readiness Guard** | Queues messages before Unity is ready, auto-flushes when the engine starts |
| **Message Batching** | Coalesces rapid-fire messages into batches to reduce native call overhead |
| **Message Throttling** | Rate-limits outgoing messages with configurable strategy (drop, keepLatest, keepFirst) |
| **Asset Streaming** | Manifest-based content downloading with SHA-256 integrity, local caching, and Unity Addressables integration |
| **Platform Views** | Android (HybridComposition / VirtualDisplay / TextureLayer), iOS (UiKitView), and web (HtmlElementView / WebGL) |
| **Transparent Rendering** | iOS: render Unity on top of Flutter widgets via `UnityConfig.transparentBackground` + alpha-0 camera clear |
| **Scene Tracking** | Automatic scene load/unload events streamed from Unity to Flutter |
| **Message Routing** | Register type-specific callbacks with `MessageHandler` for clean event dispatching |
| **Project Validator** | Editor menu `Tools ▸ UnityKit ▸ Validate Project` checks export settings before you ship |
| **Structured Exceptions** | Exception hierarchy: `UnityKitException` -> `BridgeException`, `CommunicationException`, `LifecycleException`, `EngineNotReadyException` |

---

## Platform support

| Platform | Status |
|----------|--------|
| Android | ✅ Full (player + bridge + views) |
| iOS | ✅ Full (player + bridge + views, transparent rendering) |
| Web (WebGL) | ✅ Bridge + view via `HtmlElementView`; ship a Unity WebGL build and expose `window.unityKitCreateInstance` (see `UnityKitWeb` docs) |
| macOS / Windows / Linux | 🚧 Plugin loads and the Dart bridge API is callable; embedded player view is a work in progress (tracks upstream Unity desktop-as-a-library) |

---

## Installation

### 1. Add dependency

```yaml
# pubspec.yaml
dependencies:
  unity_kit: ^2.0.0
```

Or install via command line:

```bash
flutter pub add unity_kit
```

### 2. Android setup

**`android/app/build.gradle`**:

```groovy
android {
    defaultConfig {
        minSdkVersion 22 // Unity requires API 22+
        ndk {
            abiFilters 'armeabi-v7a', 'arm64-v8a'
        }
    }
}
```

**`android/build.gradle`** -- add the Unity export as a flat directory:

```groovy
allprojects {
    repositories {
        flatDir {
            dirs "${project(':unityLibrary').projectDir}/libs"
        }
    }
}
```

**`android/settings.gradle`** -- include the Unity library:

```groovy
include ':unityLibrary'
project(':unityLibrary').projectDir = file('./unityLibrary')
```

### 3. iOS setup

**`ios/Podfile`**:

```ruby
platform :ios, '13.0'

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'NO'
    end
  end
end
```

Export the Unity project as an iOS framework and include it in your Runner workspace.

### 4. Unity setup

1. Open your Unity project (2022.3 LTS or later).
2. Copy the C# scripts from `unity/Assets/Scripts/UnityKit/` into your Unity `Assets/` folder.
3. Create an empty `GameObject` named `FlutterBridge` in your initial scene.
4. Attach the `FlutterBridge` component and (optionally) `SceneTracker` and `MessageBatcher`.
5. Mark the GameObject as `DontDestroyOnLoad` (this is automatic via the `FlutterBridge` script).
6. Build for the target platform and export.

---

### 5. Web setup (optional)

Build your Unity project for **WebGL** and host the output with your Flutter web
app, then expose the loader and let unity_kit drive it:

```html
<!-- web/index.html -->
<script src="unity/Build/unity.loader.js"></script>
<script>
  // unity_kit calls this to create the player into the canvas it manages.
  window.unityKitCreateInstance = (canvas, config) =>
    createUnityInstance(canvas, {
      dataUrl: 'unity/Build/unity.data',
      frameworkUrl: 'unity/Build/unity.framework.js',
      codeUrl: 'unity/Build/unity.wasm',
      ...config,
    });
</script>
```

`UnityView` renders an `HtmlElementView` on web automatically. Unity reports
back through `window.unityKitSendToFlutter(json)`, which unity_kit installs.

### Desktop (macOS / Windows / Linux)

The desktop plugins register the method channel so the Dart bridge API is
callable, but the embedded Unity player view is still a work in progress
(tracking upstream Unity desktop-as-a-library). `UnityView` shows a placeholder
on desktop for now.

## Quick Start

```dart
import 'package:unity_kit/unity_kit.dart';

// 1. Create the bridge (independent of any widget)
final bridge = UnityBridgeImpl(platform: UnityKitPlatform.instance);
await bridge.initialize();

// 2. Embed the Unity view
UnityView(
  bridge: bridge,
  config: const UnityConfig(sceneName: 'MainScene'),
  placeholder: const UnityPlaceholder(message: 'Loading 3D...'),
  onReady: (bridge) {
    bridge.send(UnityMessage.command('StartGame'));
  },
  onMessage: (message) {
    print('From Unity: ${message.type}');
  },
  onSceneLoaded: (scene) {
    print('Scene loaded: ${scene.name}');
  },
);

// 3. Clean up
await bridge.dispose();
```

The bridge is intentionally independent of the widget. You can create it in a
service layer, pass it to multiple widgets, and dispose it on your own terms.
When `UnityView` receives an external bridge, it **never** disposes it -- the
widget only disposes bridges it creates internally.

---

## Communication

### Flutter to Unity

```dart
// Simple command (sends to FlutterBridge.ReceiveMessage by default)
await bridge.send(UnityMessage.command('LoadScene', {'name': 'Level1'}));

// Target a specific GameObject and method
await bridge.send(UnityMessage.to('EnemyManager', 'SpawnWave', {'count': 5}));

// Queue until Unity is ready (auto-flushes when engine starts)
await bridge.sendWhenReady(UnityMessage.command('Init', {'userId': '123'}));
```

### Unity to Flutter

```dart
// Listen to all messages
bridge.messageStream.listen((msg) {
  switch (msg.type) {
    case 'score_updated':
      final score = msg.data?['score'] as int?;
      // update UI
    case 'game_over':
      // show results
  }
});

// Listen to lifecycle events
bridge.eventStream.listen((event) {
  print('Event: ${event.type} at ${event.timestamp}');
});

// Listen to scene loads
bridge.sceneStream.listen((scene) {
  print('Scene: ${scene.name}, loaded: ${scene.isLoaded}');
});

// Listen to lifecycle state changes
bridge.lifecycleStream.listen((state) {
  print('State: $state, active: ${state.isActive}');
});
```

### Type-specific handlers

```dart
final handler = MessageHandler();
handler.on('score_updated', (msg) => updateScore(msg.data));
handler.on('game_over', (msg) => showGameOver());
handler.on('error', (msg) => handleError(msg.data));

handler.listenTo(bridge.messageStream);

// Cleanup
handler.dispose();
```

---

## Binary Protocol

For high-frequency traffic (per-frame transforms, input deltas) the JSON
envelope's repeated keys add up. `bridge.sendBinary()` encodes the message
with `UnityBinaryCodec` — a compact, length-prefixed frame — and delivers it to
the Unity `ReceiveBinary` entry point.

```dart
// Same UnityMessage API, compact wire format.
await bridge.sendBinary(
  UnityMessage.command('Move', {'x': 1.5, 'y': -2.0}),
);

// Queue until Unity is ready, like sendWhenReady.
await bridge.sendBinaryWhenReady(UnityMessage.command('Spawn'));
```

For fully hand-packed payloads (no JSON at all), use the typed writer/reader:

```dart
final bytes = (UnityBinaryWriter()
      ..writeString('player')
      ..writeFloat64(x)
      ..writeFloat64(y))
    .takeBytes();

final reader = UnityBinaryReader(bytes);
final id = reader.readString();   // 'player'
final px = reader.readFloat64();  // x
```

The frame layout is symmetric with the Unity-side `UnityKitBinaryCodec`, and the
exact bytes are locked by cross-language golden tests on both sides. On mobile the
frame travels base64-encoded over the existing `UnitySendMessage` transport, so no
extra native wiring is required.

## Lifecycle Management

The Unity player follows a strict state machine. Invalid transitions throw
`LifecycleException`.

```
                                +--------+
                                | disposed |
                                +--------+
                                  ^  ^  ^
                                  |  |  |
  +---------------+    +--------+ |  |  |  +--------+    +---------+
  | uninitialized |--->| init.. |-+  |  +--| paused |<-->| resumed |
  +---------------+    +--------+    |     +--------+    +---------+
                           |         |        ^
                           v         |        |
                        +-------+----+--------+
                        | ready |
                        +-------+
```

**Valid transitions:**

| From | To |
|------|-----|
| `uninitialized` | `initializing` |
| `initializing` | `ready`, `disposed` |
| `ready` | `paused`, `disposed` |
| `paused` | `resumed`, `disposed` |
| `resumed` | `paused`, `disposed` |
| `disposed` | *(terminal)* |

Access lifecycle state:

```dart
bridge.currentState; // UnityLifecycleState.ready
bridge.isReady;      // true

await bridge.pause();
await bridge.resume();
await bridge.unload(); // resets to uninitialized, keeps process
await bridge.dispose(); // terminal, cannot reuse
```

---

## Configuration

```dart
const config = UnityConfig(
  sceneName: 'GameScene',       // Scene to load on init (default: 'MainScene')
  fullscreen: false,            // Fullscreen Unity rendering (default: false)
  unloadOnDispose: true,        // Unload Unity on widget dispose (default: true)
  hideStatusBar: false,         // Hide system status bar (default: false)
  runImmediately: true,         // Start player immediately (default: true)
  targetFrameRate: 60,          // Target FPS (default: 60)
  platformViewMode: PlatformViewMode.hybridComposition, // Android only
  transparentBackground: false, // Transparent Unity layer on iOS (default: false)
);

// Convenience factory for fullscreen
final fullscreenConfig = UnityConfig.fullscreen(sceneName: 'GameScene');

// Copy with modifications
final modified = config.copyWith(targetFrameRate: 30);
```

### PlatformViewMode (Android only)

| Mode | Performance | Compatibility | Notes |
|------|-------------|---------------|-------|
| `hybridComposition` | Good | Best | Default. Recommended for most cases. |
| `virtualDisplay` | Better | Good | Potential z-ordering and input issues. |
| `textureLayer` | Best | Limited | Limited platform support. |

### Transparent Unity layer (iOS)

Set `transparentBackground: true` to render Unity on top of Flutter widgets
without an opaque background. The native iOS container (and the Unity root
view hierarchy) are marked `isOpaque = false` with a clear background colour.

**Unity side — required** (without this the camera still paints a solid colour
behind your 3D objects):

1. Select your scene's main camera.
2. Set **Clear Flags** → `Solid Color`.
3. Set **Background** → RGBA `(0, 0, 0, 0)` (alpha must be `0`).

```dart
UnityView(
  config: const UnityConfig(
    sceneName: 'AvatarScene',
    transparentBackground: true,
  ),
)
```

> **Note:** iOS only. On Android the flag is ignored and a warning is logged
> via `UnityKitLogger`. Raise an issue if you need Android support.

---

## AR Foundation

`UnityConfig.ar()` configures a Unity view for an AR Foundation session driven
by the Unity project (ARCore / ARKit). `UnityArMode` controls compositing:

| Mode | Effect |
|------|--------|
| `none` | No AR (default). |
| `passthrough` | AR session active; Unity renders the camera feed itself (opaque). |
| `overlay` | AR session active; Unity clears to transparent so the camera feed / Flutter content shows through. Automatically enables transparent rendering. |

```dart
UnityView(
  config: UnityConfig.ar(sceneName: 'ArScene', mode: UnityArMode.overlay),
  onReady: (bridge) => bridge.send(UnityMessage.command('StartTracking')),
)
```

The `arMode` and `sceneName` are forwarded to the native host: iOS enables a
transparent surface for `overlay`, and both platforms send a `__unitykit_init`
message that the Unity-side `UnityKitGameManager` consumes (it starts the
`UnityKitArSession` and exposes `InitialSceneName` / `InitialArMode`). Wire
`UnityKitArSession`'s `onSessionStart` / `onSessionStop` events to your
`ARSession` component to start and stop tracking.

## Asset Streaming

`unity_kit` includes a full asset streaming pipeline that downloads content
bundles from a CDN, caches them locally with SHA-256 integrity verification,
and tells Unity Addressables to load from the local cache.

### Manifest format

Host a JSON manifest on your CDN:

```json
{
  "version": "1.0.0",
  "baseUrl": "https://cdn.example.com/bundles",
  "platform": "android",
  "bundles": [
    {
      "name": "core",
      "url": "https://cdn.example.com/bundles/core.bin",
      "sizeBytes": 5242880,
      "sha256": "a1b2c3...",
      "isBase": true
    },
    {
      "name": "characters",
      "url": "https://cdn.example.com/bundles/characters.bin",
      "sizeBytes": 10485760,
      "sha256": "d4e5f6...",
      "isBase": false,
      "group": "characters",
      "dependencies": ["core"]
    }
  ]
}
```

### Usage

```dart
// 1. Create streaming controller
final streaming = StreamingController(
  bridge: bridge,
  manifestUrl: 'https://cdn.example.com/manifest.json',
);

// 2. Initialize (fetches manifest, sets up cache, informs Unity)
await streaming.initialize();

// 3. Track progress
streaming.downloadProgress.listen((progress) {
  print('${progress.bundleName}: ${progress.percentageString}');
  print('Speed: ${progress.speedString}, ETA: ${progress.etaString}');
});

streaming.errors.listen((error) {
  print('Error: ${error.type} - ${error.message}');
});

// 4. Preload base content
await streaming.preloadContent();

// 5. Load a specific bundle on demand
await streaming.loadBundle('characters');

// 6. Load a Unity scene via Addressables
await streaming.loadScene('BattleArena', loadMode: 'Additive');

// 7. Cache management
final cached = streaming.getCachedBundles();
final size = streaming.getCacheSize();
final isCached = streaming.isBundleCached('characters');
await streaming.clearCache();

// 8. Dispose
await streaming.dispose();
```

### ContentDownloader (advanced)

For more granular control over downloads (retries, concurrency, cancellation):

```dart
final downloader = ContentDownloader(
  cacheManager: CacheManager(),
  maxRetries: 3,
  maxConcurrency: 3,
);

await for (final progress in downloader.downloadBundle(bundle)) {
  print('${progress.percentageString} - ${progress.speedString}');
}

// Cancel specific download
downloader.cancelDownload('characters');
downloader.cancelAllDownloads();

downloader.dispose();
```

### Unity asset loading

`unity_kit` supports two asset loading strategies on the Unity side:

| Strategy | Unity component | When to use |
|----------|----------------|-------------|
| **Addressables** | `FlutterAddressablesManager` | Recommended. Requires Unity Addressables package. |
| **Raw AssetBundles** | `FlutterAssetBundleManager` | Simpler setup, no extra Unity packages needed. |

Both use the same `StreamingController` API on the Flutter side. See **[doc/asset-streaming.md](doc/asset-streaming.md)** for the full setup guide.

#### Addressables setup

1. Install the **Addressables** package in Unity (Window > Package Manager).
2. Add the `ADDRESSABLES_INSTALLED` scripting define symbol:
   - Edit > Project Settings > Player > Other Settings > Scripting Define Symbols.
3. Attach `FlutterAddressablesManager` to the same `FlutterBridge` GameObject.
4. Mark your assets and scenes as Addressable in the Unity Editor.
5. Build Addressables content (Window > Asset Management > Addressables > Build).

#### Raw AssetBundles setup

1. Attach `FlutterAssetBundleManager` to the `FlutterBridge` GameObject.
2. Build AssetBundles (Window > AssetBundles > Build).
3. Host bundles on a CDN and create a manifest (see [doc/asset-streaming.md](doc/asset-streaming.md)).

When Flutter calls `streaming.loadBundle('characters')`, the flow is:

```
Flutter                          Native Cache                  Unity
  |                                  |                           |
  |-- download bundle ------------->|                           |
  |                                  |-- write to disk          |
  |-- sendWhenReady(LoadAsset) -----|-------------------------->|
  |                                  |                           |
  |                                  |<--- Addressables checks  |
  |                                  |     local cache first    |
  |                                  |                           |
  |<------- asset_loaded response --|---------------------------|
```

---

## Unity C# Setup

### FlutterBridge (required)

Singleton `MonoBehaviour` that receives all messages from Flutter. Attach to a
`GameObject` named `FlutterBridge` in your startup scene.

```csharp
// FlutterBridge auto-sends a "ready" signal on Start().
// You can disable this with sendReadyOnStart = false in the Inspector.
```

### FlutterMonoBehaviour (recommended)

Base class for any `MonoBehaviour` that communicates with Flutter. Auto-registers
with `MessageRouter` on enable, auto-unregisters on disable.

```csharp
using UnityKit;

public class EnemyManager : FlutterMonoBehaviour
{
    protected override void OnFlutterMessage(string method, string data)
    {
        switch (method)
        {
            case "SpawnWave":
                // parse data, spawn enemies
                break;
            case "Reset":
                // reset game state
                break;
        }
    }

    private void OnWaveCleared()
    {
        // Direct send
        SendToFlutter("wave_cleared", "{\"wave\": 3}");

        // Batched send (via MessageBatcher component on FlutterBridge)
        SendToFlutterBatched("score_updated", "{\"score\": 1500}");
    }
}
```

### MessageRouter

Static registry that routes messages from `FlutterBridge.ReceiveMessage()` to
the correct `FlutterMonoBehaviour` by target name. Manual registration is also
possible:

```csharp
MessageRouter.Register("CustomTarget", (method, data) => {
    Debug.Log($"Received: {method} with {data}");
});

MessageRouter.Unregister("CustomTarget");
```

### SceneTracker

Attach alongside `FlutterBridge` to automatically notify Flutter when scenes
load or unload. No configuration needed.

### MessageBatcher (C#)

Batches outgoing Unity-to-Flutter messages per frame. All queued messages are
sent as a JSON array in `LateUpdate()`.

```csharp
var batcher = FlutterBridge.Instance.GetComponent<MessageBatcher>();
batcher.Send("position_update", "{\"x\": 1.5}");
batcher.Send("rotation_update", "{\"y\": 90}");
// Both sent as a single batch at end of frame
```

### NativeAPI

Low-level native bridge. You typically do not call this directly -- use
`FlutterMonoBehaviour.SendToFlutter()` or `MessageBatcher.Send()` instead.

---

### `[UnityKitMethod]` attribute dispatch

Expose C# methods to Flutter by name — no manual `switch`:

```csharp
public class PlayerController : MonoBehaviour
{
    [UnityKitMethod]               // callable as "Jump"
    public void Jump() { /* ... */ }

    [UnityKitMethod("move")]       // callable as "move"
    public void Move(MovePayload p) { /* p deserialized from JSON */ }

    void OnEnable()  => MessageRouter.RegisterMethods("player", this);
    void OnDisable() => MessageRouter.Unregister("player");
}
```

From Flutter, route to it via `UnityMessage.routed('player', 'Jump')`.

### UnityKitGameManager

High-level lifecycle MonoBehaviour (auto-created). Handles `LoadScene`,
`UnloadScene`, `SetTargetFrameRate`, `PauseGame` / `ResumeGame` from Flutter,
and consumes the native `__unitykit_init` message (scene name + AR mode).

### UnityKitPerformanceMonitor

Samples FPS / frame time / memory and streams them to
`bridge.performanceStream`. See [Performance monitoring](#performance-monitoring-unity--flutter).

### UnityKitArSession

AR session bridge (`ArSession` target). Responds to `start` / `stop` /
`setMode`, manages the camera clear colour for overlay AR, and exposes
`onSessionStart` / `onSessionStop` UnityEvents to hook your `ARSession`.

### UnityKitBinaryCodec

Decodes the base64 binary frames sent by `bridge.sendBinary()` and encodes
frames back to Flutter. Wired into `FlutterBridge.ReceiveBinary`.

### Project validator (Editor)

Run **Tools ▸ UnityKit ▸ Validate Project** before exporting. It checks the
build scene list, scripting backend, ARM64, and Android min SDK.

> **Assembly definitions.** The scripts ship with `UnityKit.asmdef` (runtime),
> `UnityKit.Editor.asmdef`, and `UnityKit.Tests.asmdef` (EditMode tests). If your
> project lacks the Addressables or iOS-build modules, remove the matching
> entries from the `references` list in the Inspector.

## Performance

### Message Batching (Dart)

Reduces native call overhead by coalescing messages within a time window.
Messages with the same `gameObject:method` key are deduplicated (last value wins).

```dart
final bridge = UnityBridgeImpl(
  platform: UnityKitPlatform.instance,
  batcher: MessageBatcher(
    flushInterval: const Duration(milliseconds: 16), // ~1 frame at 60fps
    maxBatchSize: 10,                                 // Flush immediately at 10
    onFlush: (messages) async {
      for (final msg in messages) {
        await platform.postMessage(msg.gameObject, msg.method, msg.toJson());
      }
    },
  ),
);

// Stats
print('Batched: ${batcher.totalBatched}');
print('Flushed: ${batcher.totalFlushed}');
print('Avg batch size: ${batcher.averageBatchSize}');
```

### Message Throttling (Dart)

Rate-limits messages to prevent flooding Unity.

```dart
final bridge = UnityBridgeImpl(
  platform: UnityKitPlatform.instance,
  throttler: MessageThrottler(
    window: const Duration(milliseconds: 100),
    strategy: ThrottleStrategy.keepLatest,
  ),
);
```

| Strategy | Behavior |
|----------|----------|
| `ThrottleStrategy.drop` | Drop all messages during the window |
| `ThrottleStrategy.keepLatest` | Keep only the newest message (default) |
| `ThrottleStrategy.keepFirst` | Keep only the first message, drop subsequent |

```dart
// Stats
print('Total: ${throttler.totalThrottled}');
print('Sent: ${throttler.totalSent}');
print('Dropped: ${throttler.totalDropped}');
print('Currently throttling: ${throttler.isThrottling}');
```

---

### Performance monitoring (Unity → Flutter)

Attach the `UnityKitPerformanceMonitor` MonoBehaviour in Unity and subscribe to
`bridge.performanceStream` for live frame stats:

```dart
bridge.performanceStream.listen((stats) {
  debugPrint('${stats.fps.toStringAsFixed(0)} fps  '
      '${stats.frameTimeMs.toStringAsFixed(1)} ms  '
      '${stats.usedMemoryMb.toStringAsFixed(0)} MB');
});
```

`UnityPerformanceStats` carries `fps`, `frameTimeMs`, `usedMemoryMb`,
`drawCalls`, and `triangles`. The bundled monitor reports FPS, frame time, and
memory (the runtime has no cross-platform draw-call API; the fields are kept for
projects that supply their own source). The sample interval and FPS smoothing
are configurable on the component.

## Resolved Issues

Common Flutter + Unity integration problems and how `unity_kit` solves them:

| # | Issue | Solution |
|---|-------|----------|
| 1 | Bridge destroyed when widget rebuilds | Bridge is independent of widget. External bridges survive widget disposal. |
| 2 | Messages sent before Unity is ready | `ReadinessGuard` queues messages; `sendWhenReady()` auto-flushes on ready. |
| 3 | App crash on background/foreground | `UnityLifecycleMixin` and `UnityView` auto-pause/resume on app lifecycle. |
| 4 | Untyped string messages | `UnityMessage` with `type`, `data`, `gameObject`, `method` fields and factory constructors. |
| 5 | Message flooding causes frame drops | `MessageThrottler` rate-limits outgoing messages; `MessageBatcher` coalesces. |
| 6 | No scene load tracking | `SceneTracker` (C#) + `sceneStream` (Dart) auto-report scene events. |
| 7 | Invalid lifecycle transitions | `LifecycleManager` enforces state machine; throws `LifecycleException` on invalid transitions. |
| 8 | Large asset download blocks startup | `StreamingController` downloads content in background with progress tracking. |
| 9 | Cache integrity issues | `CacheManager` stores SHA-256 hashes, supports `verifyCache()` for integrity checks. |
| 10 | Platform view rendering issues on Android | `PlatformViewMode` enum with three modes to tune rendering vs. compatibility. |

---

## Migration from flutter_unity_widget

| flutter_unity_widget | unity_kit |
|---------------------|-----------|
| `UnityWidget(onUnityCreated: ...)` | `UnityView(bridge: bridge, onReady: ...)` |
| `controller.postMessage(go, method, data)` | `bridge.send(UnityMessage.to(go, method, data))` |
| `onUnityMessage: (msg) => ...` | `bridge.messageStream.listen(...)` or `onMessage:` callback |
| No lifecycle management | `bridge.pause()`, `bridge.resume()`, `bridge.unload()` |
| No readiness guard | `bridge.sendWhenReady(message)` |
| No message batching | `MessageBatcher(flushInterval: ..., onFlush: ...)` |
| No asset streaming | `StreamingController(bridge: ..., manifestUrl: ...)` |
| `UnityMessageManager.Instance.SendMessageToFlutter(msg)` | `NativeAPI.SendToFlutter(json)` or `FlutterMonoBehaviour.SendToFlutter(type, data)` |

---

## API Reference

Full API documentation with class signatures, parameters, and code examples:
**[doc/api.md](doc/api.md)**

---

## Why Addressables?

Traditional Flutter + Unity apps ship **all** 3D assets inside the APK/IPA, resulting
in app sizes of 500 MB -- several GB. With `unity_kit`'s Addressables integration,
your app binary can stay around **~100 MB** while downloading content dynamically
on demand.

| Approach | App size | First launch | Update strategy |
|----------|----------|--------------|-----------------|
| All assets in APK/IPA | 500 MB -- 3+ GB | Slow (huge download) | Full app update |
| **Addressables + unity_kit** | **~100 MB** | Fast (base app only) | Download changed bundles only |

How it works:

1. **Base app** ships with minimal assets (UI, loading screens).
2. **Content bundles** (characters, levels, textures) are hosted on a CDN.
3. `StreamingController` fetches a manifest, downloads bundles on demand,
   caches them locally with SHA-256 integrity, and tells Unity Addressables
   to load from the local cache.
4. **Updates** only download changed bundles -- no full app update required.

This means users get a fast install, and you can push new 3D content, levels,
or cosmetics without going through app store review.

---

## License

See [LICENSE](LICENSE) for details.
