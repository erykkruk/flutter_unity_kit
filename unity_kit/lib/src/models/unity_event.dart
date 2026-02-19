import 'unity_event_type.dart';
import 'unity_lifecycle_state.dart';

/// An event emitted by the Unity player.
class UnityEvent {
  /// Creates a new [UnityEvent].
  const UnityEvent({
    required this.type,
    required this.timestamp,
    this.message,
    this.error,
  });

  /// Creates a 'created' event.
  factory UnityEvent.created() {
    return UnityEvent(
      type: UnityEventType.created,
      timestamp: DateTime.now(),
    );
  }

  /// Creates an 'error' event.
  factory UnityEvent.error(String errorMessage) {
    return UnityEvent(
      type: UnityEventType.error,
      timestamp: DateTime.now(),
      error: errorMessage,
    );
  }

  /// Creates a 'sceneLoaded' event.
  factory UnityEvent.sceneLoaded(String sceneName) {
    return UnityEvent(
      type: UnityEventType.sceneLoaded,
      timestamp: DateTime.now(),
      message: sceneName,
    );
  }

  /// Creates a 'message' event.
  factory UnityEvent.message(String content) {
    return UnityEvent(
      type: UnityEventType.message,
      timestamp: DateTime.now(),
      message: content,
    );
  }

  /// Creates an event from a lifecycle state transition.
  factory UnityEvent.fromState(UnityLifecycleState state) {
    final type = switch (state) {
      UnityLifecycleState.initializing => UnityEventType.created,
      UnityLifecycleState.ready => UnityEventType.loaded,
      UnityLifecycleState.paused => UnityEventType.paused,
      UnityLifecycleState.resumed => UnityEventType.resumed,
      UnityLifecycleState.disposed => UnityEventType.destroyed,
      UnityLifecycleState.uninitialized => UnityEventType.unloaded,
    };
    return UnityEvent(type: type, timestamp: DateTime.now());
  }

  /// The type of event.
  final UnityEventType type;

  /// When the event occurred.
  final DateTime timestamp;

  /// Optional message content.
  final String? message;

  /// Optional error description.
  final String? error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnityEvent &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          message == other.message &&
          error == other.error;

  @override
  int get hashCode => Object.hash(type, message, error);

  @override
  String toString() =>
      'UnityEvent(type: $type, message: $message, error: $error)';
}
