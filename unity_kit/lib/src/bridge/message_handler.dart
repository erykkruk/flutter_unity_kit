import 'dart:async';

import '../models/models.dart';

/// Callback type for handling a specific Unity message type.
typedef MessageCallback = void Function(UnityMessage message);

/// Routes incoming Unity messages to registered handlers by type.
///
/// Example:
/// ```dart
/// final handler = MessageHandler();
/// handler.on('scene_loaded', (msg) => debugPrint('Scene: ${msg.data}'));
/// handler.on('error', (msg) => debugPrint('Error: ${msg.data}'));
///
/// // Connect to bridge
/// bridge.onMessage.listen(handler.handle);
///
/// // Cleanup
/// handler.dispose();
/// ```
class MessageHandler {
  final Map<String, List<MessageCallback>> _handlers = {};
  final List<StreamSubscription<UnityMessage>> _subscriptions = [];

  /// Register a handler for a specific message [type].
  void on(String type, MessageCallback callback) {
    _handlers.putIfAbsent(type, () => []).add(callback);
  }

  /// Remove a specific handler for a message [type].
  void off(String type, MessageCallback callback) {
    _handlers[type]?.remove(callback);
  }

  /// Remove all handlers for a message [type].
  void offAll(String type) {
    _handlers.remove(type);
  }

  /// Handle an incoming [message] by routing to registered callbacks.
  void handle(UnityMessage message) {
    final callbacks = _handlers[message.type];
    if (callbacks == null) return;

    for (final callback in callbacks) {
      callback(message);
    }
  }

  /// Subscribe this handler to a message [stream] from [UnityBridge].
  void listenTo(Stream<UnityMessage> stream) {
    final subscription = stream.listen(handle);
    _subscriptions.add(subscription);
  }

  /// Cancel all stream subscriptions and clear handlers.
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _handlers.clear();
  }
}
