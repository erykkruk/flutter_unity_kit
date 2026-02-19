import 'unity_kit_exception.dart';

/// Exception thrown when attempting to communicate with Unity before it is ready.
class EngineNotReadyException extends UnityKitException {
  /// Creates a new [EngineNotReadyException].
  const EngineNotReadyException({
    super.cause,
    super.stackTrace,
  }) : super(
          message:
              'Unity engine is not ready. Call initialize() first or use sendWhenReady().',
        );

  @override
  String toString() => 'EngineNotReadyException: $message';
}
