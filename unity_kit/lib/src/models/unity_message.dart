import 'dart:convert';

/// A typed message exchanged between Flutter and Unity.
///
/// Example:
/// ```dart
/// // Command to Unity
/// final msg = UnityMessage.command('LoadScene', {'name': 'Level1'});
///
/// // Event from Unity
/// final event = UnityMessage.fromJson('{"type":"scene_loaded","data":"Level1"}');
/// ```
class UnityMessage {
  /// Creates a new [UnityMessage].
  const UnityMessage({
    required this.type,
    this.data,
    this.gameObject = 'FlutterBridge',
    this.method = 'ReceiveMessage',
  });

  /// Creates a command message to send to Unity.
  factory UnityMessage.command(String action, [Map<String, dynamic>? data]) {
    return UnityMessage(
      type: action,
      data: data,
    );
  }

  /// Creates a message targeting a specific Unity GameObject and method.
  factory UnityMessage.to(
    String gameObject,
    String method, [
    Map<String, dynamic>? data,
  ]) {
    return UnityMessage(
      type: method,
      data: data,
      gameObject: gameObject,
      method: method,
    );
  }

  /// Parses a JSON string received from Unity.
  ///
  /// Throws [FormatException] if [jsonString] is not valid JSON or
  /// does not contain a 'type' field.
  factory UnityMessage.fromJson(String jsonString) {
    final decoded = json.decode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'Expected a JSON object, got ${decoded.runtimeType}',
        jsonString,
      );
    }

    final type = decoded['type'];
    if (type is! String) {
      throw FormatException(
        'Missing or invalid "type" field in Unity message',
        jsonString,
      );
    }

    return UnityMessage(
      type: type,
      data: decoded['data'] as Map<String, dynamic>?,
    );
  }

  /// Message type identifier (e.g., 'LoadScene', 'scene_loaded').
  final String type;

  /// Optional payload data.
  final Map<String, dynamic>? data;

  /// Target Unity GameObject name.
  final String gameObject;

  /// Target method name on the GameObject.
  final String method;

  /// Serializes this message to a JSON string for sending to Unity.
  String toJson() {
    return json.encode({
      'type': type,
      if (data != null) 'data': data,
    });
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnityMessage &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          gameObject == other.gameObject &&
          method == other.method;

  @override
  int get hashCode => Object.hash(type, gameObject, method);

  @override
  String toString() => 'UnityMessage(type: $type, data: $data)';
}
