import 'unity_kit_exception.dart';

/// Exception thrown when a message cannot be delivered.
class CommunicationException extends UnityKitException {
  /// Creates a new [CommunicationException].
  const CommunicationException({
    required super.message,
    this.target,
    this.method,
    this.data,
    super.cause,
    super.stackTrace,
  });

  /// The target GameObject.
  final String? target;

  /// The method name.
  final String? method;

  /// The message data.
  final String? data;

  @override
  String toString() {
    final buffer = StringBuffer('CommunicationException: $message');
    if (target != null) buffer.write(' (target: $target)');
    if (method != null) buffer.write(' (method: $method)');
    return buffer.toString();
  }
}
