import Foundation

/// Registry that connects Unity C# bridge callbacks to Flutter view controllers.
///
/// Unity's C# side calls `[DllImport("__Internal")]` C functions which route
/// through this registry to find the correct `UnityKitViewController` for the
/// active view. Multiple views are supported via `viewId` keys.
///
/// The `@objc` attribute and class name make this discoverable from
/// UnityFramework's Objective-C runtime via `NSClassFromString`.
///
/// Controllers are stored via weak wrappers to prevent retain cycles (iOS-C3).
@objc(FlutterBridgeRegistry)
public class FlutterBridgeRegistry: NSObject {

    // MARK: - Weak Wrapper (iOS-C3)

    private final class WeakController {
        weak var value: UnityKitViewController?
        init(_ value: UnityKitViewController) { self.value = value }
    }

    // MARK: - Storage

    private static let lock = NSLock()
    private static var controllers: [Int: WeakController] = [:]

    // MARK: - Registration

    /// Register a view controller for a specific view ID.
    @objc public static func register(viewId: Int, controller: UnityKitViewController) {
        lock.lock()
        defer { lock.unlock() }

        controllers[viewId] = WeakController(controller)
        NSLog("[UnityKit] FlutterBridgeRegistry: registered viewId=\(viewId)")
    }

    /// Remove a view controller by its view ID.
    @objc public static func unregister(viewId: Int) {
        lock.lock()
        defer { lock.unlock() }

        controllers.removeValue(forKey: viewId)
        NSLog("[UnityKit] FlutterBridgeRegistry: unregistered viewId=\(viewId)")
    }

    // MARK: - Message Dispatch

    /// Forward a Unity message to all registered controllers.
    ///
    /// Called from `@_cdecl` bridge functions when Unity sends a message via
    /// `UnityMessageManager.Instance.SendMessageToFlutter()`.
    @objc public static func sendMessageToFlutter(_ message: String) {
        lock.lock()
        // Unwrap weak values and clean nil entries (iOS-C3).
        controllers = controllers.filter { $0.value.value != nil }
        let snapshot = controllers.values.compactMap { $0.value }
        lock.unlock()

        for controller in snapshot {
            controller.onMessage(message)
        }
    }

    /// Forward a scene-loaded event to all registered controllers.
    @objc public static func sendSceneLoadedToFlutter(
        _ name: String,
        buildIndex: Int32,
        isLoaded: Bool,
        isValid: Bool
    ) {
        lock.lock()
        // Unwrap weak values and clean nil entries (iOS-C3).
        controllers = controllers.filter { $0.value.value != nil }
        let snapshot = controllers.values.compactMap { $0.value }
        lock.unlock()

        for controller in snapshot {
            controller.onSceneLoaded(name, buildIndex: buildIndex, isLoaded: isLoaded, isValid: isValid)
        }
    }

    // MARK: - Lookup

    /// Returns the number of registered controllers (with live references).
    @objc public static var count: Int {
        lock.lock()
        defer { lock.unlock() }
        // Clean nil entries before counting (iOS-C3).
        controllers = controllers.filter { $0.value.value != nil }
        return controllers.count
    }
}

// MARK: - C Bridge Functions
//
// The C symbols `SendMessageToFlutter` and `SendSceneLoadedToFlutter` are
// defined in UnityKitNativeBridge.mm (Unity Assets/Plugins/iOS/). That file
// is compiled into UnityFramework.framework and forwards calls to this
// class via Objective-C runtime lookup (NSClassFromString + performSelector).
//
// Previously these were @_cdecl functions here, but that caused duplicate
// symbol errors because the same symbols must also exist in
// UnityFramework for the IL2CPP linker to resolve them.
