/// Lifecycle states for the Unity player.
enum UnityLifecycleState {
  /// Initial state before any initialization.
  uninitialized,

  /// Unity player is being initialized.
  initializing,

  /// Unity player is ready and accepting messages.
  ready,

  /// Unity player is paused (app in background).
  paused,

  /// Unity player has been resumed from pause.
  resumed,

  /// Unity player has been disposed and cannot be reused.
  disposed,
}

/// Extensions for [UnityLifecycleState].
extension UnityLifecycleStateExtension on UnityLifecycleState {
  /// Whether the player is in an active state (ready or resumed).
  bool get isActive =>
      this == UnityLifecycleState.ready || this == UnityLifecycleState.resumed;

  /// Whether messages can be sent in this state.
  bool get canSend => isActive;

  /// Whether a transition to [target] is valid from the current state.
  bool canTransitionTo(UnityLifecycleState target) {
    switch (this) {
      case UnityLifecycleState.uninitialized:
        return target == UnityLifecycleState.initializing;
      case UnityLifecycleState.initializing:
        return target == UnityLifecycleState.ready ||
            target == UnityLifecycleState.disposed;
      case UnityLifecycleState.ready:
        return target == UnityLifecycleState.paused ||
            target == UnityLifecycleState.disposed;
      case UnityLifecycleState.paused:
        return target == UnityLifecycleState.resumed ||
            target == UnityLifecycleState.disposed;
      case UnityLifecycleState.resumed:
        return target == UnityLifecycleState.paused ||
            target == UnityLifecycleState.disposed;
      case UnityLifecycleState.disposed:
        return false;
    }
  }
}
