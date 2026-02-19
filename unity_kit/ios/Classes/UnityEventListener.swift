import Foundation

/// Protocol for receiving Unity player events.
///
/// Implemented by view controllers that need to react to Unity lifecycle
/// and messaging events. Uses `@objc` for Objective-C runtime compatibility
/// with UnityFramework callbacks.
@objc protocol UnityEventListener: AnyObject {

    /// Called when Unity sends a message to Flutter.
    ///
    /// - Parameter message: Raw message string from Unity's
    ///   `UnityMessageManager.Instance.SendMessageToFlutter()`.
    func onMessage(_ message: String)

    /// Called when a Unity scene finishes loading.
    ///
    /// - Parameters:
    ///   - name: Scene name.
    ///   - buildIndex: Scene build index.
    ///   - isLoaded: Whether the scene is loaded.
    ///   - isValid: Whether the scene reference is valid.
    func onSceneLoaded(_ name: String, buildIndex: Int32, isLoaded: Bool, isValid: Bool)

    /// Called when the Unity player is created and ready.
    func onCreated()

    /// Called when the Unity player has been unloaded.
    func onUnloaded()
}
