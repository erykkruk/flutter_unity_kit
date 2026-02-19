import '../models/unity_lifecycle_state.dart';
import 'unity_kit_exception.dart';

/// Exception thrown for invalid lifecycle state transitions.
class LifecycleException extends UnityKitException {
  /// Creates a new [LifecycleException].
  LifecycleException({
    required this.currentState,
    required this.attemptedAction,
    super.cause,
    super.stackTrace,
  }) : super(
          message:
              'Invalid lifecycle action "$attemptedAction" in state $currentState',
        );

  /// The state when the invalid action was attempted.
  final UnityLifecycleState currentState;

  /// The action that was attempted.
  final String attemptedAction;

  @override
  String toString() =>
      'LifecycleException: Cannot $attemptedAction in state $currentState';
}
