/// Classification of streaming errors.
enum StreamingErrorType {
  /// The streaming subsystem has not been initialized.
  notInitialized,

  /// Initialization failed (cache setup, permissions, etc.).
  initializationFailed,

  /// Could not fetch the content manifest from the server.
  manifestFetchFailed,

  /// The requested bundle name does not exist in the manifest.
  bundleNotFound,

  /// A bundle download failed (network error, disk full, etc.).
  downloadFailed,

  /// No suitable network connection is available.
  networkUnavailable,

  /// An error occurred while reading or writing the local cache.
  cacheError,
}

/// A structured error produced by the streaming subsystem.
///
/// Example:
/// ```dart
/// const error = StreamingError(
///   type: StreamingErrorType.downloadFailed,
///   message: 'Connection timed out after 30s',
/// );
/// ```
class StreamingError {
  /// Creates a new [StreamingError].
  const StreamingError({
    required this.type,
    required this.message,
    this.cause,
  });

  /// The classification of this error.
  final StreamingErrorType type;

  /// A human-readable description of what went wrong.
  final String message;

  /// The underlying exception or error, if any.
  final Object? cause;

  @override
  String toString() => 'StreamingError($type): $message';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreamingError &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          message == other.message;

  @override
  int get hashCode => type.hashCode ^ message.hashCode;
}
