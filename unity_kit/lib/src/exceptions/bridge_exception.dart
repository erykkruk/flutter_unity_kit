import 'unity_kit_exception.dart';

/// Exception thrown when bridge communication fails.
class BridgeException extends UnityKitException {
  /// Creates a new [BridgeException].
  const BridgeException({
    required super.message,
    super.cause,
    super.stackTrace,
  });

  @override
  String toString() => 'BridgeException: $message';
}
