import 'dart:async';

import '../models/models.dart';

/// Accumulates messages within a time window and flushes them as a batch.
///
/// Reduces native call overhead by combining multiple messages into
/// single batch sends. Messages with the same `gameObject:method` key
/// are coalesced (last value wins).
///
/// Example:
/// ```dart
/// final batcher = MessageBatcher(
///   flushInterval: const Duration(milliseconds: 16),
///   maxBatchSize: 10,
///   onFlush: (messages) async {
///     for (final msg in messages) {
///       await controller.postMessage(msg.gameObject, msg.method, msg.toJson());
///     }
///   },
/// );
///
/// batcher.add(UnityMessage.command('UpdatePosition', {'x': 1.0}));
/// batcher.add(UnityMessage.command('UpdatePosition', {'x': 2.0}));
/// // Only the second message is sent (coalesced by key).
///
/// batcher.dispose();
/// ```
class MessageBatcher {
  /// Creates a [MessageBatcher].
  ///
  /// [flushInterval] controls the time window for accumulating messages.
  /// [maxBatchSize] triggers an immediate flush when reached.
  /// [onFlush] is called with the batch of messages to send.
  MessageBatcher({
    this.flushInterval = const Duration(milliseconds: 16),
    this.maxBatchSize = 10,
    required this.onFlush,
  });

  /// Time window for accumulating messages before flushing (~1 frame at 60fps).
  final Duration flushInterval;

  /// Maximum messages per batch before triggering an immediate flush.
  final int maxBatchSize;

  /// Callback invoked with the batch of messages to send.
  final Future<void> Function(List<UnityMessage> messages) onFlush;

  Timer? _timer;
  final Map<String, UnityMessage> _pending = {};
  bool _isDisposed = false;

  int _totalBatched = 0;
  int _totalFlushed = 0;
  int _totalFlushes = 0;

  /// Total number of messages added via [add].
  int get totalBatched => _totalBatched;

  /// Total number of messages actually sent via [onFlush].
  int get totalFlushed => _totalFlushed;

  /// Average number of messages per flush.
  double get averageBatchSize =>
      _totalFlushes == 0 ? 0 : _totalFlushed / _totalFlushes;

  /// Number of messages waiting to be flushed.
  int get pendingCount => _pending.length;

  /// Add a message to the current batch.
  ///
  /// Coalescing: messages with the same `gameObject:method` key overwrite
  /// previous entries (last value wins). If [maxBatchSize] is reached,
  /// the batch is flushed immediately.
  void add(UnityMessage message) {
    if (_isDisposed) return;

    final key = '${message.gameObject}:${message.method}';
    _pending[key] = message;
    _totalBatched++;

    if (_pending.length >= maxBatchSize) {
      flush();
      return;
    }

    _timer ??= Timer(flushInterval, flush);
  }

  /// Flush all pending messages immediately.
  ///
  /// Cancels the pending timer and invokes [onFlush] with
  /// the accumulated batch. No-op if no messages are pending.
  void flush() {
    _timer?.cancel();
    _timer = null;

    if (_pending.isEmpty || _isDisposed) return;

    final batch = _pending.values.toList();
    _pending.clear();
    _totalFlushed += batch.length;
    _totalFlushes++;

    // Fire and forget but log errors
    onFlush(batch).catchError((Object error, StackTrace stackTrace) {
      // Errors are logged by the caller's error handler
    });
  }

  /// Dispose the batcher, cancelling any pending timer and clearing the queue.
  ///
  /// After calling this, [add] becomes a no-op.
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _timer = null;
    _pending.clear();
  }
}
