# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.2] - 2026-07-10

### Docs
- Linked the full hosted documentation at
  [codigee.com/open-source/unity-kit](https://codigee.com/open-source/unity-kit)
  from `pubspec.yaml` (`documentation:`) and added a prominent **Documentation**
  section to the README covering the step-by-step walkthrough, native setup
  (Android/iOS), Unity export, content loading, API reference, asset streaming,
  architecture, and FAQ.

## [2.0.1] - 2026-07-09

### Fixed
- **`MissingPluginException` after the active `UnityView` is disposed**
  ([#4](https://github.com/erykkruk/flutter_unity_kit/issues/4)). When the
  platform view backing the active `UnityView` was destroyed (e.g. the screen
  was popped), the Dart side kept targeting the dead
  `com.unity_kit/unity_view_N` channel and the bridge stayed `ready`, so the
  next `send`/`sendWhenReady` crashed with `MissingPluginException`. Native
  (iOS + Android) now emits an `onViewDisposed` notification before tearing
  the channel down; the bridge resets readiness back to `initializing`, so
  `sendWhenReady()` queues messages until the next `UnityView` attaches and
  `send()` throws a typed `EngineNotReadyException` instead.
- **Duplicate platform events after re-`initialize()`.** Calling
  `UnityBridgeImpl.initialize()` again after `unload()` subscribed to the
  platform event stream a second time, duplicating every message/event.
  The previous subscription is now cancelled first.

## [2.0.0] - 2026-06-10

### Breaking
- **Minimum SDK raised to Dart `3.4` / Flutter `3.22`** (required by the modern
  `dart:js_interop` web implementation). Existing mobile API usage is unchanged.
- **`UnityBridge` gained `sendBinary`, `sendBinaryWhenReady`, and
  `performanceStream`.** Code that *calls* the bridge is unaffected; only code
  that directly `implements UnityBridge` (e.g. custom mocks) must add the three
  members. `UnityBridgeImpl` and the bundled mocks already do.

### Added
- **Binary protocol.** `UnityBinaryCodec` compact wire format with
  `UnityBridge.sendBinary()` / `sendBinaryWhenReady()`, plus
  `UnityBinaryWriter` / `UnityBinaryReader` for hand-packed payloads. Mirrored
  on the Unity side by `UnityKitBinaryCodec` + `FlutterBridge.ReceiveBinary`.
- **Performance monitoring.** `UnityBridge.performanceStream` emitting
  `UnityPerformanceStats` (FPS, frame time, used memory), produced by the new
  `UnityKitPerformanceMonitor` MonoBehaviour.
- **AR Foundation.** `UnityConfig.ar()` factory and `UnityArMode`
  (`none` / `passthrough` / `overlay`), wired to native creation params and a
  dependency-free `UnityKitArSession` bridge on the Unity side.
- **Attribute dispatch.** `[UnityKitMethod]` attribute +
  `MessageRouter.RegisterMethods(target, instance)` to expose C# methods to
  Flutter by name via reflection.
- **Game manager.** `UnityKitGameManager` MonoBehaviour handling
  load/unload scene, target frame rate, and pause/resume from Flutter.
- **Web (WebGL) support.** `UnityKitWeb` plugin registering the
  `com.unity_kit/unity_view` platform view via `HtmlElementView`, bridging
  through the per-view method channel.
- **Desktop scaffolding.** macOS / Windows / Linux plugins register the method
  channel so the Dart bridge API is callable; embedded player view is WIP.
- **Project validator.** Editor menu `Tools ▸ UnityKit ▸ Validate Project`.
- `UnityConfig.toCreationParams()` as the single source of truth for the
  Dart → native config contract (now also carries `sceneName` and `arMode`).

### Changed
- `UnityView` now renders an `HtmlElementView` on web.
- iOS and Android now read `arMode` / `sceneName` from the view creation
  params: `UnityArMode.overlay` enables transparent rendering automatically,
  and both values are forwarded to Unity as a `__unitykit_init` message that
  `UnityKitGameManager` consumes.

## [1.1.1] - 2026-06-07

### Added
- `UnityConfig.embedded()` factory for creating an embedded (non-fullscreen)
  Unity view configuration, mirroring the existing `UnityConfig.fullscreen()`
  factory. Optionally accepts `transparentBackground`.

## [1.1.0] - 2026-04-20

### Added
- `UnityConfig.transparentBackground` flag that renders the native Unity
  container non-opaque on iOS so Flutter widgets painted behind the
  platform view can show through. Requires the Unity scene camera's
  clear colour to use alpha `0`.
- `UnityConfig.fullscreen()` factory now accepts `transparentBackground`.
- iOS `UnityKitView` recursively applies `isOpaque = false` and a clear
  background to the Unity root view hierarchy when the flag is enabled.

### Changed
- `UnityConfig.toString()` now reports every field, including
  `transparentBackground`, so it stays in sync with `==` / `hashCode`.
- `UnityView` logs a warning via `UnityKitLogger` when
  `transparentBackground` is enabled on Android (iOS-only feature).

## [1.0.3] - 2026-04-07

### Changed
- Updated installation docs to ^1.0.3

## [1.0.2] - 2026-04-07

### Changed
- Android `compileSdk`: 34 → 35
- `androidx.lifecycle`: 2.7.0 → 2.8.7
- `androidx.annotation`: 1.7.1 → 1.9.1

## [1.0.1] - 2026-03-27

### Fixed

- **iOS: Unity view re-navigation** — `detachUnityView()` now checks `superview === self` before removing, preventing race conditions when a new container has already claimed the Unity view.
- **iOS: Rendering restart** — added `restartRendering()` to `UnityPlayerManager` that calls `showUnityWindow()` after view reattachment, ensuring AR subsystems (e.g. Vuforia) reinitialize properly.
- **iOS: CocoaPods dangling symlink** — podspec no longer uses `File.symlink?` which returns `true` for dangling symlinks, causing CocoaPods `realpath` to fail with ENOENT.
- **Dart: Active view channel routing** — all platform method calls now use `_activeViewId` instead of hardcoded `0`, ensuring correct MethodChannel routing after Flutter navigation creates new platform views.
- Added `registerViewChannel(int viewId)` to `UnityKitPlatform` — automatically called when a new platform view is created on both Android (Hybrid Composition) and iOS (UiKitView).

## [1.0.0] - 2026-03-27

### Changed

- **Stable release** — API is now considered stable. Follows Semantic Versioning from this point.
- `_RoutedUnityMessage` now exposes logical `gameObject`, `method`, `type`, and `data` properties matching the actual target (e.g. `FlutterAddressablesManager`), while routing through `FlutterBridge.ReceiveMessage` at the native layer via `nativeGameObject`/`nativeMethod`.

### Added

- `UnityMessage.nativeGameObject` and `UnityMessage.nativeMethod` getters for accessing the native `UnitySendMessage` target separately from the logical message properties.
- `UnityAssetLoader.loadContentCatalogMessage` — request Unity to load a remote content catalog by URL (Addressables).
- "Why Addressables?" section in README — explains how dynamic content delivery keeps app size ~100 MB instead of 500 MB+.

### Fixed

- All 22 previously failing tests in `streaming/` and `loaders/` now pass — routed messages correctly expose target info through standard `UnityMessage` properties.

## [0.9.2] - 2026-03-18

### Fixed

- **Android display bug:** Unity view no longer renders on top of all Flutter widgets, covering the entire screen regardless of layout bounds ([#1](https://github.com/erykkruk/flutter_unity_kit/issues/1)).
  - Switched Android rendering from Virtual Display (`AndroidView`) to Hybrid Composition (`PlatformViewLink` + `initExpensiveAndroidView`) for correct z-ordering and bounds clipping.
  - Applied `setZOrderOnTop(false)` on Unity's `SurfaceView` after attachment.
  - Added delayed re-focus (500ms) to ensure rendering starts after Hybrid Composition finishes surface setup.

### Documentation

- Added ARM64 export requirement to unity-export.md — exporting only ARMv7 causes Unity player to silently fail on arm64 devices.
- Added troubleshooting entry for "Unity view never loads on Android".

## [0.9.1] - 2026-02-20

### Fixed

- Fixed `.pubignore` excluding `models/` directory from published package, causing 159 analysis errors on pub.dev.
- Removed unused `connectivity_plus` dependency.

## [0.9.0] - 2026-02-19

### Added

- Gesture controls for `UnityView` (`gestureRecognizers` parameter).
- CocoaPods support for iOS integration.
- Target frame rate configuration (`UnityConfig.targetFrameRate`).
- Touch event handling for Android and iOS.
- Flutter Android lifecycle integration.
- Core bridge: `UnityBridge`, `UnityBridgeImpl` with typed messaging.
- Lifecycle management: 6-state machine (`uninitialized` → `ready` → `paused` → `resumed` → `disposed`).
- Readiness guard: auto-queue messages until Unity is ready.
- Message batching (~16ms windows, coalescing).
- Message throttling (3 strategies: `drop`, `keepLatest`, `keepFirst`).
- Asset streaming: manifest-based, SHA-256 integrity, caching.
- Content downloading with exponential backoff.
- Addressables and AssetBundle loaders.
- `UnityView` widget with platform views (Android HybridComposition + iOS UiKitView).
- `UnityPlaceholder` loading widget.
- `UnityLifecycleMixin` for app pause/resume handling.
- Typed exception hierarchy (`UnityKitException`, `BridgeException`, `CommunicationException`, `LifecycleException`, `EngineNotReadyException`).
- `UnityConfig`, `UnityMessage`, `SceneInfo` models.
- Platform abstraction via `MethodChannel`.
- C# Unity scripts (`FlutterBridge`, `MessageRouter`, `MessageBatcher`, `SceneTracker`, `NativeAPI`, `FlutterMonoBehaviour`).
- Comprehensive test suite (35 files, ~9000 lines).
- API documentation and asset streaming guide.
