import 'dart:async';

import '../exceptions/exceptions.dart';
import '../models/models.dart';
import '../utils/logger.dart';

/// Queued message waiting to be sent when Unity is ready.
class _QueuedMessage {
  const _QueuedMessage(this.message, this.sender);

  final UnityMessage message;
  final Future<void> Function(UnityMessage) sender;
}

/// Guards against sending messages before Unity is ready.
///
/// Provides two modes:
/// - [guard]: throws [EngineNotReadyException] if not ready.
/// - [queueUntilReady]: queues messages and flushes when [markReady] is called.
///
/// Example:
/// ```dart
/// final guard = ReadinessGuard();
///
/// // Mode 1: Throw if not ready
/// guard.guard(); // throws EngineNotReadyException
///
/// // Mode 2: Queue until ready
/// guard.queueUntilReady(message, controller.send);
/// await guard.markReady(); // flushes queued messages
/// ```
class ReadinessGuard {
  /// Creates a [ReadinessGuard] with an optional [maxQueueSize].
  ///
  /// When the queue exceeds [maxQueueSize], the oldest message is dropped.
  ReadinessGuard({this.maxQueueSize = 100});

  /// Maximum number of messages that can be queued.
  final int maxQueueSize;

  bool _isReady = false;
  final List<_QueuedMessage> _queue = [];

  /// Whether Unity is ready to receive messages.
  bool get isReady => _isReady;

  /// Number of messages currently queued.
  int get queueLength => _queue.length;

  /// Throws [EngineNotReadyException] if Unity is not ready.
  void guard() {
    if (!_isReady) throw const EngineNotReadyException();
  }

  /// Queues a [message] until Unity is ready, then sends via [sender].
  ///
  /// If already ready, sends immediately without queuing.
  /// If the queue is full, the oldest message is dropped.
  void queueUntilReady(
    UnityMessage message,
    Future<void> Function(UnityMessage) sender,
  ) {
    if (_isReady) {
      sender(message);
      return;
    }

    if (_queue.length >= maxQueueSize) {
      _queue.removeAt(0);
      UnityKitLogger.instance.warning('Queue full, dropping oldest message');
    }

    _queue.add(_QueuedMessage(message, sender));
  }

  /// Marks Unity as ready and flushes all queued messages in order.
  Future<void> markReady() async {
    _isReady = true;

    for (final queued in _queue) {
      await queued.sender(queued.message);
    }

    _queue.clear();
  }

  /// Resets to not-ready state and clears the queue.
  void reset() {
    _isReady = false;
    _queue.clear();
  }

  /// Disposes the guard and clears all queued messages.
  void dispose() {
    _queue.clear();
  }
}
