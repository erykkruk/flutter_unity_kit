# iOS Integration Guide -- Unity 6000 Patterns

This document captures critical findings from debugging the iOS native integration layer for `unity_kit`, specifically the patterns required for Unity 6000 (Unity 6) compatibility with Flutter.

**Reference library:** [flutter_embed_unity](https://github.com/nickmeinhold/flutter_embed_unity) -- has a working Unity 6000 iOS implementation that served as architectural reference.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [UnityFramework Integration](#unityframework-integration)
- [Native Bridge (.mm)](#native-bridge-mm)
- [Auto-initialization](#auto-initialization)
- [Metal Texture Zero-Size Crash](#metal-texture-zero-size-crash)
- [View Attachment](#view-attachment)
- [Message Flow](#message-flow)
- [Podspec Configuration](#podspec-configuration)
- [Complete Integration Flow](#complete-integration-flow)
- [Known Issues and Workarounds](#known-issues-and-workarounds)

---

## Architecture Overview

The iOS native layer consists of:

```
Swift Plugin Code (unity_kit/ios/Classes/)
+-- SwiftUnityKitPlugin.swift        (FlutterPlugin entry point, view factory registration)
+-- UnityKitViewFactory.swift        (FlutterPlatformViewFactory)
+-- UnityKitViewController.swift     (FlutterPlatformView + MethodChannel handler)
+-- UnityKitView.swift               (UIView container for Unity view)
+-- UnityPlayerManager.swift         (Singleton Unity player lifecycle)
+-- FlutterBridgeRegistry.swift      (Routes Unity messages to Flutter controllers)
+-- UnityEventListener.swift         (Protocol for Unity event callbacks)

Native Bridge (compiled into UnityFramework)
+-- UnityKitNativeBridge.mm          (C symbols for IL2CPP DllImport)
```

**Key difference from Android:** On iOS, Unity runs as `UnityFramework.framework` -- a separate framework embedded in the app. The C# `[DllImport("__Internal")]` calls resolve to C symbols that must exist within `UnityFramework` at link time, not in the Flutter plugin.

---

## UnityFramework Integration

### How Unity embeds on iOS

Unity exports an Xcode project that builds `UnityFramework.framework`. This framework contains:
- The Unity runtime and renderer (Metal-based)
- IL2CPP-compiled C# code (including `NativeAPI.cs`)
- Data files (scenes, assets, shaders)

The Flutter plugin loads `UnityFramework.framework` at runtime:

```swift
private func loadFramework() -> UnityFramework? {
    let bundlePath = Bundle.main.bundlePath + "/Frameworks/UnityFramework.framework"
    guard let bundle = Bundle(path: bundlePath) else { return nil }

    if !bundle.isLoaded {
        bundle.load()
    }

    guard let framework = bundle.principalClass?.getInstance() as? UnityFramework else {
        return nil
    }

    return framework
}
```

### UnityPlayerManager singleton

Unity only supports a single instance per process. `UnityPlayerManager` owns that instance and survives Flutter navigation:

```swift
final class UnityPlayerManager: NSObject {
    static let shared = UnityPlayerManager()

    func initialize() -> Bool {
        // Load UnityFramework.framework
        // Set data bundle ID
        // Register as listener
        // Run embedded with command line args
        // Set window level below Flutter's window
    }

    func getView() -> UIView? {
        // Returns framework.appController()?.rootView
    }

    func sendMessage(gameObject: String, methodName: String, message: String) {
        // framework.sendMessageToGO(withName:functionName:message:)
    }
}
```

### Window level management

Flutter's window must stay above Unity's window. After initialization:

```swift
if let window = framework.appController()?.window {
    window.windowLevel = UIWindow.Level(UIWindow.Level.normal.rawValue - 1)
}
```

This ensures Flutter's UI renders on top of Unity's full-screen rendering surface.

---

## Native Bridge (.mm)

### The problem

C# code in Unity uses `[DllImport("__Internal")]` to declare native functions:

```csharp
// In NativeAPI.cs
[DllImport("__Internal")]
private static extern void SendMessageToFlutter(string message);

[DllImport("__Internal")]
private static extern void SendSceneLoadedToFlutter(
    string sceneName, int buildIndex, bool isLoaded, bool isValid);
```

IL2CPP compiles these into C function calls. The linker requires these symbols to exist in the same binary -- `UnityFramework.framework`. The Swift plugin runs in a separate module (`unity_kit.framework`), so Swift `@_cdecl` functions are not visible to the UnityFramework linker.

### The solution

An Objective-C++ file (`UnityKitNativeBridge.mm`) provides the C symbols and forwards calls to `FlutterBridgeRegistry` via ObjC runtime:

```
Unity C# (IL2CPP) --[DllImport]--> C symbols in .mm --[ObjC runtime]--> FlutterBridgeRegistry (Swift)
```

**Location:** `unity_kit/unity/Assets/Plugins/iOS/UnityKitNativeBridge.mm`

This file is placed in the Unity project's `Assets/Plugins/iOS/` folder so Unity's build system automatically includes it in the Xcode export. It gets compiled into `UnityFramework.framework`.

### Implementation details

```objc
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static const NSUInteger kMaxMessageSize = 1048576; // 1 MB

extern "C" {

void SendMessageToFlutter(const char* message) {
    if (message == NULL) return;
    size_t length = strnlen(message, kMaxMessageSize + 1);
    if (length > kMaxMessageSize) return;

    NSString *msg = [NSString stringWithUTF8String:message];

    // Dispatch to main thread (Unity calls from render thread)
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"FlutterBridgeRegistry");
        if (cls == nil) return;
        SEL sel = NSSelectorFromString(@"sendMessageToFlutter:");
        if ([cls respondsToSelector:sel]) {
            [cls performSelector:sel withObject:msg];
        }
    });
}

void SendSceneLoadedToFlutter(const char* name, int buildIndex,
                               bool isLoaded, bool isValid) {
    NSString *sceneName = name ? [NSString stringWithUTF8String:name] : @"";
    // ... dispatch to main thread via NSInvocation
}

} // extern "C"
```

**Key design decisions:**

1. **ObjC runtime lookup** (`NSClassFromString`) -- The `.mm` file is compiled into `UnityFramework`, which doesn't link against the Flutter plugin. It discovers `FlutterBridgeRegistry` at runtime via the ObjC runtime, since both are loaded in the same process.

2. **Main thread dispatch** -- Unity calls these functions from the render thread. Flutter's `MethodChannel` requires main thread access. `dispatch_async(dispatch_get_main_queue(), ...)` ensures thread safety.

3. **Message size validation** -- Prevents buffer overflow by checking `strnlen` before `stringWithUTF8String:`.

4. **NSInvocation for multi-argument calls** -- `performSelector:` only supports one object argument. For `SendSceneLoadedToFlutter` (4 arguments including primitives), `NSInvocation` is used instead.

### Why not @_cdecl in Swift?

The initial approach used `@_cdecl` in `FlutterBridgeRegistry.swift`:

```swift
// DOES NOT WORK -- these symbols are in unity_kit.framework, not UnityFramework
@_cdecl("SendMessageToFlutter")
func sendMessageToFlutterC(_ message: UnsafePointer<CChar>) { ... }
```

This fails because:
- `@_cdecl` exports the symbol from `unity_kit.framework`
- IL2CPP linker looks for the symbol in `UnityFramework.framework`
- Different binaries → "Undefined symbol" linker error

The `.mm` file solves this by being compiled directly into `UnityFramework`.

---

## Auto-initialization

### The pattern

On iOS, the `UnityKitViewController` auto-initializes Unity when the platform view is created, mirroring Android's behavior:

```
init() → waitForNonZeroFrame() → autoInitialize() → waitForUnityView()
```

### waitForNonZeroFrame

Unity's Metal renderer creates textures matching the root view size. If initialized before the platform view has layout, it gets a 0×0 frame and crashes:

```
MTLTextureDescriptor has width of zero
```

The solution polls until the container view has non-zero bounds:

```swift
private func waitForNonZeroFrame(attempt: Int = 0) {
    guard !isDisposed else { return }

    if !containerView.bounds.isEmpty {
        autoInitialize()
    } else if attempt < 20 {
        // Poll every 50ms for up to 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50)) {
            [weak self] in
            self?.waitForNonZeroFrame(attempt: attempt + 1)
        }
    } else {
        // Timeout -- proceed anyway (may fail, but logs the attempt)
        autoInitialize()
    }
}
```

### autoInitialize

Initializes the `UnityPlayerManager` singleton if needed, then waits for the Unity view:

```swift
private func autoInitialize() {
    guard !isDisposed else { return }

    let manager = UnityPlayerManager.shared
    if !manager.isInitialized {
        let success = manager.initialize()
        if !success {
            sendEvent(name: "onError",
                      data: ["message": "Failed to initialize Unity framework"])
            return
        }
    }

    waitForUnityView(attempt: 0, maxAttempts: 30)
}
```

### Comparison with Android

| Aspect | Android | iOS |
|--------|---------|-----|
| Deferred init | `Handler.postDelayed(100ms)` | `waitForNonZeroFrame()` polling |
| Why deferred | Activity binding not complete | Metal textures need non-zero view size |
| Player creation | Reflection for Unity 6 vs legacy | `UnityFramework.framework` API |
| View extraction | `getFrameLayout()` via reflection | `appController()?.rootView` |
| Rendering activation | `windowFocusChanged` + pause/resume | Not needed (framework handles it) |

---

## Metal Texture Zero-Size Crash

### The problem

```
*** Terminating app due to uncaught exception 'NSInvalidArgumentException'
*** reason: '-[MTLTextureDescriptorInternal validateWithDevice:]:
    MTLTextureDescriptor has width of zero.'
```

This crash occurs when Unity creates Metal render textures before the container view has been laid out by UIKit. The texture dimensions are derived from the view bounds, which are (0, 0) during initial platform view creation.

### The solution

Two-layer protection:

1. **waitForNonZeroFrame** -- Polls until `containerView.bounds.isEmpty == false` before calling `autoInitialize()`.

2. **Bounds guard in waitForUnityView** -- Even after auto-init, the view attachment retries check bounds:

```swift
private func waitForUnityView(attempt: Int, maxAttempts: Int) {
    guard !isDisposed else { return }

    // Don't attach if container still has zero bounds
    guard !containerView.bounds.isEmpty else {
        if attempt < maxAttempts {
            let delayMs = 100 * (attempt + 1)  // Linear backoff
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs)) {
                [weak self] in
                self?.waitForUnityView(attempt: attempt + 1, maxAttempts: maxAttempts)
            }
        }
        return
    }

    if let unityView = UnityPlayerManager.shared.getView() {
        containerView.attachUnityView(unityView)
        sendEvent(name: "onUnityCreated", data: nil)
    } else if attempt < maxAttempts {
        // Linear backoff retry
        // ...
    }
}
```

---

## View Attachment

### UnityKitView container

The `UnityKitView` is a simple `UIView` container that hosts the Unity root view:

```swift
final class UnityKitView: UIView {
    func attachUnityView(_ unityView: UIView) {
        unityView.removeFromSuperview()
        unityView.frame = bounds
        unityView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(unityView)
    }

    func detachUnityView() {
        subviews.forEach { $0.removeFromSuperview() }
    }
}
```

### Dart side: UiKitView

On the Dart/Flutter side, iOS uses `UiKitView`:

```dart
UiKitView(
  viewType: 'com.unity_kit/unity_view',
  creationParams: config.toMap(),
  creationParamsCodec: const StandardMessageCodec(),
)
```

Unlike Android (which requires choosing between Virtual Display and Hybrid Composition), iOS always uses `UiKitView` with composition.

---

## Message Flow

### Unity → Flutter

```
Unity C# (NativeAPI.SendToFlutter)
    ↓ [DllImport("__Internal")]
UnityKitNativeBridge.mm (SendMessageToFlutter)
    ↓ dispatch_async(main_queue)
FlutterBridgeRegistry.sendMessageToFlutter (ObjC runtime lookup)
    ↓ iterate registered controllers
UnityKitViewController.onMessage
    ↓ channel.invokeMethod
Dart MethodChannel (onUnityMessage event)
    ↓
UnityBridgeImpl.messageStream
```

### Flutter → Unity

```
Dart bridge.send(UnityMessage)
    ↓ MethodChannel
UnityKitViewController.handlePostMessage
    ↓ enqueueOrSend (queue if not ready)
UnityPlayerManager.sendMessage
    ↓ framework.sendMessageToGO
Unity C# (FlutterBridge.ReceiveMessage)
    ↓ MessageRouter
Target MonoBehaviour handler
```

### Scene notifications

```
Unity (SceneManager.sceneLoaded)
    ↓ SceneTracker.cs
NativeAPI.NotifySceneLoaded
    ↓ [DllImport("__Internal")]
UnityKitNativeBridge.mm (SendSceneLoadedToFlutter)
    ↓ dispatch_async + NSInvocation
FlutterBridgeRegistry.sendSceneLoadedToFlutter
    ↓
UnityKitViewController.onSceneLoaded
    ↓ channel.invokeMethod
Dart (bridge.sceneStream)
```

---

## Podspec Configuration

The `unity_kit.podspec` must be configured to find `UnityFramework.framework`:

```ruby
Pod::Spec.new do |s|
  s.name             = 'unity_kit'
  s.platform         = :ios, '13.0'
  s.source_files     = 'Classes/**/*'

  # Vendored framework support (when symlinked or copied)
  unity_framework_path = File.join(__dir__, 'UnityFramework.framework')
  if File.exist?(unity_framework_path) || File.symlink?(unity_framework_path)
    s.ios.vendored_frameworks = 'UnityFramework.framework'
    s.preserve_paths = 'UnityFramework.framework'
  end

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'FRAMEWORK_SEARCH_PATHS' =>
      '$(inherited) "${PODS_TARGET_SRCROOT}" "${PODS_CONFIGURATION_BUILD_DIR}"',
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
  }
end
```

### UnityFramework symlink

For local development, create a symlink from the plugin's `ios/` directory to the built framework:

```bash
cd unity_kit/ios
ln -s /path/to/Unity/Builds/ios/build/Release-iphoneos/UnityFramework.framework .
```

### Building UnityFramework

After exporting the Unity project for iOS:

```bash
# Build UnityFramework from the Unity export
xcodebuild \
  -project /path/to/Builds/ios/Unity-iPhone.xcodeproj \
  -scheme UnityFramework \
  -configuration Release \
  -sdk iphoneos \
  -arch arm64 \
  ONLY_ACTIVE_ARCH=NO \
  BUILD_DIR=/path/to/Builds/ios/build
```

The resulting framework is at: `build/Release-iphoneos/UnityFramework.framework`

**Important:** The `UnityKitNativeBridge.mm` file must be included in the UnityFramework target's "Compile Sources" build phase. If placed in `Assets/Plugins/iOS/` before export, Unity includes it automatically.

---

## Complete Integration Flow

The full initialization sequence on iOS:

```
1. Flutter creates UiKitView with viewType "com.unity_kit/unity_view"
2. UnityKitViewFactory.create() creates UnityKitViewController
3. init() registers with FlutterBridgeRegistry + UnityPlayerManager
4. waitForNonZeroFrame() polls every 50ms for non-zero container bounds
5. autoInitialize():
   a. UnityPlayerManager.shared.initialize()
   b. Loads UnityFramework.framework from app bundle
   c. Sets data bundle ID, registers as listener
   d. Runs framework embedded with argc/argv
   e. Sets Unity window level below Flutter's window
6. waitForUnityView() with linear backoff (100ms, 200ms, 300ms...):
   a. Check containerView.bounds is non-empty
   b. Try UnityPlayerManager.shared.getView()
   c. If available: attach to container, mark channel ready
7. Send "onUnityCreated" event to Flutter via MethodChannel
8. markChannelReady() flushes any queued messages
9. FlutterBridge.Start() sends {"type":"ready"} via NativeAPI
10. NativeAPI → [DllImport] → .mm → ObjC runtime → FlutterBridgeRegistry
11. Dart bridge transitions to ready state, flushes queued messages
```

---

## Known Issues and Workarounds

### MTLTextureDescriptor zero-size crash

**Cause:** Unity creates Metal textures before the container view has been laid out.

**Fix:** `waitForNonZeroFrame()` polling before initialization. See [Metal Texture Zero-Size Crash](#metal-texture-zero-size-crash).

### NSLog not visible in `flutter run` output

**Cause:** `flutter run` only forwards `Debug.Log` (Unity C#) and `print()` (Dart). iOS `NSLog` from Swift plugins is not captured.

**Workaround:** For debugging, send diagnostic info through MethodChannel to Dart:

```swift
sendEvent(name: "onUnityMessage", data: "debug:myInfo value=\(someValue)")
```

Then check Dart console output. Remove debug messages before production.

### Unity view not available after initialization

**Cause:** `appController()?.rootView` returns nil briefly after `runEmbedded()` completes. Unity needs time to create its view hierarchy.

**Fix:** Linear backoff retry in `waitForUnityView()` with up to 30 attempts. Delay = `100ms * (attempt + 1)`.

### Duplicate onUnityCreated events

**Cause:** Both `autoInitialize()` and `handleCreatePlayer()` can trigger `waitForUnityView()`, which sends the event.

**Fix:** `markChannelReady()` uses an `isChannelReady` flag -- once set, subsequent calls are no-ops.

### Messages sent before Unity is ready

**Cause:** Flutter sends messages via MethodChannel before the native side has attached the Unity view.

**Fix:** `enqueueOrSend()` pattern: if `isChannelReady` is false, messages are queued (up to 100). When `markChannelReady()` fires, all queued messages are flushed.

### App lifecycle forwarding

**Cause:** Unity's `UnityAppController` expects to receive app lifecycle notifications (background, foreground, memory warnings). Without forwarding, Unity may not properly pause/resume rendering.

**Fix:** `UnityPlayerManager` observes `UIApplication` notifications and forwards them to `framework.appController()`:

```swift
@objc private func handleAppLifecycle(_ notification: Notification) {
    let appController = framework?.appController()
    let application = UIApplication.shared

    switch notification.name {
    case UIApplication.didBecomeActiveNotification:
        appController?.applicationDidBecomeActive(application)
    case UIApplication.willResignActiveNotification:
        appController?.applicationWillResignActive(application)
    // ... other lifecycle events
    }
}
```

### Simulator not supported

**Cause:** `UnityFramework.framework` is built for `arm64` device architecture only. iOS Simulator on Intel Macs uses `x86_64`.

**Fix:** Always test on physical devices. The podspec excludes `i386` from simulator builds:

```ruby
'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
```

On Apple Silicon Macs, the simulator runs arm64 but UnityFramework may still have compatibility issues with the simulator runtime.

### Thread safety

**Cause:** Unity calls `SendMessageToFlutter` from the render thread. FlutterMethodChannel operations must happen on the main thread.

**Fix:** All calls in `UnityKitNativeBridge.mm` use `dispatch_async(dispatch_get_main_queue(), ...)`. Additionally, `UnityPlayerManager` and `UnityKitViewController` use `NSLock` for mutable state access.
