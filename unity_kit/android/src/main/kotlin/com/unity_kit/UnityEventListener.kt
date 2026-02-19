package com.unity_kit

/// Listener interface for Unity player events.
///
/// Implementations receive callbacks when the Unity player emits events
/// such as messages, scene loads, creation, and unloading.
interface UnityEventListener {
    /// Called when Unity sends a message to Flutter.
    fun onMessage(message: String)

    /// Called when a Unity scene finishes loading.
    fun onSceneLoaded(name: String, buildIndex: Int, isLoaded: Boolean, isValid: Boolean)

    /// Called when the Unity player is created and ready.
    fun onCreated()

    /// Called when the Unity player is unloaded.
    fun onUnloaded()
}
