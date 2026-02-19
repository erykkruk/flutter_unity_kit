import 'dart:async';

import '../exceptions/exceptions.dart';
import '../models/models.dart';

/// Manages Unity player lifecycle state transitions.
///
/// Enforces valid state transitions and emits events on changes.
/// Valid transitions:
/// - uninitialized -> initializing
/// - initializing -> ready | disposed
/// - ready -> paused | disposed
/// - paused -> resumed | disposed
/// - resumed -> paused | disposed
/// - disposed -> (terminal)
///
/// Example:
/// ```dart
/// final lifecycle = LifecycleManager();
///
/// lifecycle.stateStream.listen((state) {
///   debugPrint('State changed: $state');
/// });
///
/// lifecycle.transition(UnityLifecycleState.initializing);
/// lifecycle.transition(UnityLifecycleState.ready);
/// debugPrint('${lifecycle.isActive}'); // true
///
/// lifecycle.dispose();
/// ```
class LifecycleManager {
  UnityLifecycleState _state = UnityLifecycleState.uninitialized;

  final StreamController<UnityLifecycleState> _stateController =
      StreamController<UnityLifecycleState>.broadcast();
  final StreamController<UnityEvent> _eventController =
      StreamController<UnityEvent>.broadcast();

  /// Current lifecycle state.
  UnityLifecycleState get currentState => _state;

  /// Stream of state changes.
  Stream<UnityLifecycleState> get stateStream => _stateController.stream;

  /// Stream of lifecycle events.
  Stream<UnityEvent> get eventStream => _eventController.stream;

  /// Whether the engine is in an active state (ready or resumed).
  bool get isActive => _state.isActive;

  /// Transition to a new state.
  ///
  /// Throws [LifecycleException] if the transition from [currentState]
  /// to [target] is not valid.
  void transition(UnityLifecycleState target) {
    if (!_state.canTransitionTo(target)) {
      throw LifecycleException(
        currentState: _state,
        attemptedAction: 'transition to $target',
      );
    }
    _state = target;
    _stateController.add(_state);
    _eventController.add(UnityEvent.fromState(target));
  }

  /// Reset to uninitialized state (for reuse after dispose).
  void reset() {
    _state = UnityLifecycleState.uninitialized;
  }

  /// Dispose all resources.
  ///
  /// Closes [stateStream] and [eventStream]. After calling this,
  /// the manager should not be used.
  void dispose() {
    _stateController.close();
    _eventController.close();
  }
}
