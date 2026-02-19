/// Base exception for all unity_kit errors.
class UnityKitException implements Exception {
  /// Creates a new [UnityKitException].
  const UnityKitException({
    required this.message,
    this.cause,
    this.stackTrace,
  });

  /// Human-readable error description.
  final String message;

  /// The underlying cause of this exception.
  final Object? cause;

  /// Stack trace at the point of the error.
  final StackTrace? stackTrace;

  @override
  String toString() {
    final buffer = StringBuffer('UnityKitException: $message');
    if (cause != null) buffer.write('\nCaused by: $cause');
    return buffer.toString();
  }
}
