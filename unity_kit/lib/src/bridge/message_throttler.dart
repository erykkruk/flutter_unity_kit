import 'dart:async';

import '../models/models.dart';

/// Strategy for handling messages that arrive during throttle window.
enum ThrottleStrategy {
  /// Drop messages during throttle window.
  drop,

  /// Keep only the latest message during throttle window.
  keepLatest,

  /// Keep only the first message, drop subsequent.
  keepFirst,
}

/// Rate limits messages to Unity to prevent flooding.
///
/// Example:
/// ```dart
/// final throttler = MessageThrottler(
///   window: const Duration(milliseconds: 100),
///   strategy: ThrottleStrategy.keepLatest,
/// );
///
/// throttler.throttle(message, bridge.send);
///
/// // Cleanup
/// throttler.dispose();
/// ```
class MessageThrottler {
  /// Creates a [MessageThrottler] with the given [window] and [strategy].
  MessageThrottler({
    this.window = const Duration(milliseconds: 100),
    this.strategy = ThrottleStrategy.keepLatest,
  });

  /// Throttle window duration.
  final Duration window;

  /// Strategy for handling messages within the window.
  final ThrottleStrategy strategy;

  Timer? _timer;
  UnityMessage? _pendingMessage;
  Future<void> Function(UnityMessage)? _pendingSender;
  bool _isInWindow = false;
  bool _isDisposed = false;

  int _totalThrottled = 0;
  int _totalSent = 0;
  int _totalDropped = 0;

  /// Total number of messages passed to [throttle].
  int get totalThrottled => _totalThrottled;

  /// Total number of messages actually sent through to Unity.
  int get totalSent => _totalSent;

  /// Total number of messages dropped by the throttle strategy.
  int get totalDropped => _totalDropped;

  /// Whether the throttler is currently within a throttle window.
  bool get isThrottling => _isInWindow;

  /// Throttle a [message] using the configured strategy.
  ///
  /// The [sender] callback is invoked when the message is allowed through.
  void throttle(
    UnityMessage message,
    Future<void> Function(UnityMessage) sender,
  ) {
    if (_isDisposed) return;
    _totalThrottled++;

    if (!_isInWindow) {
      _isInWindow = true;
      _totalSent++;
      sender(message).catchError((Object error, StackTrace stackTrace) {
        // Errors are logged by the caller's error handler
      });
      _timer = Timer(window, _onWindowEnd);
      return;
    }

    switch (strategy) {
      case ThrottleStrategy.drop:
        _totalDropped++;
      case ThrottleStrategy.keepLatest:
        if (_pendingMessage != null) _totalDropped++;
        _pendingMessage = message;
        _pendingSender = sender;
      case ThrottleStrategy.keepFirst:
        if (_pendingMessage == null) {
          _pendingMessage = message;
          _pendingSender = sender;
        } else {
          _totalDropped++;
        }
    }
  }

  void _onWindowEnd() {
    _isInWindow = false;
    if (_pendingMessage != null && _pendingSender != null) {
      _totalSent++;
      final msg = _pendingMessage!;
      final sender = _pendingSender!;
      _pendingMessage = null;
      _pendingSender = null;
      _isInWindow = true;
      sender(msg).catchError((Object error, StackTrace stackTrace) {
        // Errors are logged by the caller's error handler
      });
      _timer = Timer(window, _onWindowEnd);
    }
  }

  /// Dispose and cancel any active timer.
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _timer = null;
    _pendingMessage = null;
    _pendingSender = null;
  }
}
