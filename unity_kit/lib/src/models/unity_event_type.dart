/// Types of events emitted by the Unity player.
enum UnityEventType {
  /// Unity player was created.
  created,

  /// Unity scene was loaded.
  loaded,

  /// Unity player was paused.
  paused,

  /// Unity player was resumed.
  resumed,

  /// Unity scene was unloaded.
  unloaded,

  /// Unity player was destroyed.
  destroyed,

  /// An error occurred in Unity.
  error,

  /// A general message from Unity.
  message,

  /// A specific scene finished loading.
  sceneLoaded,
}
