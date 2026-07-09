import 'dart:async';

import '../exceptions/exceptions.dart';
import '../models/models.dart';
import '../platform/unity_kit_platform.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import 'lifecycle_manager.dart';
import 'message_batcher.dart';
import 'message_handler.dart';
import 'message_throttler.dart';
import 'readiness_guard.dart';
import 'unity_binary_codec.dart';

/// Abstract interface for Flutter-Unity communication.
///
/// Provides typed messaging, lifecycle management, and event streams.
///
/// Example:
/// ```dart
/// final bridge = UnityBridgeImpl(platform: UnityKitPlatform.instance);
/// await bridge.initialize();
///
/// bridge.messageStream.listen((msg) => debugPrint('Received: ${msg.type}'));
/// bridge.lifecycleStream.listen((state) => debugPrint('State: $state'));
///
/// await bridge.send(UnityMessage.command('LoadScene', {'name': 'Main'}));
/// await bridge.dispose();
/// ```
abstract class UnityBridge {
  /// Current lifecycle state of the Unity player.
  UnityLifecycleState get currentState;

  /// Whether the Unity player is ready to receive messages.
  bool get isReady;

  /// Send a message to Unity. Throws [EngineNotReadyException] if not ready.
  Future<void> send(UnityMessage message);

  /// Queue a message to be sent when Unity becomes ready.
  ///
  /// If already ready, sends immediately.
  Future<void> sendWhenReady(UnityMessage message);

  /// Send a message to Unity using the compact binary wire format.
  ///
  /// Encodes [message] with [UnityBinaryCodec] and delivers it to the Unity
  /// `ReceiveBinary` entry point. Prefer this for high-frequency traffic.
  /// Throws [EngineNotReadyException] if not ready.
  Future<void> sendBinary(UnityMessage message);

  /// Queue a binary message to be sent when Unity becomes ready.
  Future<void> sendBinaryWhenReady(UnityMessage message);

  /// Stream of messages received from Unity.
  Stream<UnityMessage> get messageStream;

  /// Stream of performance samples reported by Unity.
  ///
  /// Populated when a Unity-side performance monitor pushes frame stats.
  Stream<UnityPerformanceStats> get performanceStream;

  /// Stream of lifecycle events from the Unity player.
  Stream<UnityEvent> get eventStream;

  /// Stream of scene load/unload events as [SceneInfo].
  Stream<SceneInfo> get sceneStream;

  /// Stream of lifecycle state changes.
  Stream<UnityLifecycleState> get lifecycleStream;

  /// Initialize the Unity player and begin listening for events.
  Future<void> initialize();

  /// Pause the Unity player.
  Future<void> pause();

  /// Resume the Unity player from a paused state.
  Future<void> resume();

  /// Unload the Unity player (keeps process alive).
  Future<void> unload();

  /// Dispose all resources. The bridge cannot be reused after this.
  Future<void> dispose();
}

/// Default implementation of [UnityBridge].
///
/// Integrates [LifecycleManager], [ReadinessGuard], [MessageHandler],
/// and optional [MessageBatcher]/[MessageThrottler] for a complete
/// Flutter-Unity communication layer.
///
/// Example:
/// ```dart
/// final bridge = UnityBridgeImpl(
///   platform: UnityKitPlatform.instance,
/// );
/// await bridge.initialize();
///
/// bridge.messageStream.listen((msg) {
///   debugPrint('Message: ${msg.type}');
/// });
///
/// await bridge.send(UnityMessage.command('LoadScene', {'name': 'Main'}));
/// ```
class UnityBridgeImpl implements UnityBridge {
  /// Creates a [UnityBridgeImpl].
  ///
  /// [platform] is required for native communication.
  /// [batcher] and [throttler] are optional optimizations.
  UnityBridgeImpl({
    required UnityKitPlatform platform,
    MessageBatcher? batcher,
    MessageThrottler? throttler,
  })  : _platform = platform,
        _batcher = batcher,
        _throttler = throttler;

  final UnityKitPlatform _platform;
  final MessageBatcher? _batcher;
  final MessageThrottler? _throttler;

  final LifecycleManager _lifecycle = LifecycleManager();
  final ReadinessGuard _guard = ReadinessGuard();
  final MessageHandler _messageHandler = MessageHandler();

  final StreamController<UnityMessage> _messageController =
      StreamController<UnityMessage>.broadcast();
  final StreamController<SceneInfo> _sceneController =
      StreamController<SceneInfo>.broadcast();
  final StreamController<UnityPerformanceStats> _performanceController =
      StreamController<UnityPerformanceStats>.broadcast();

  StreamSubscription<Map<String, dynamic>>? _platformSubscription;
  bool _isDisposed = false;

  @override
  UnityLifecycleState get currentState => _lifecycle.currentState;

  @override
  bool get isReady => _guard.isReady && !_isDisposed;

  @override
  Stream<UnityMessage> get messageStream => _messageController.stream;

  @override
  Stream<UnityPerformanceStats> get performanceStream =>
      _performanceController.stream;

  @override
  Stream<UnityEvent> get eventStream => _lifecycle.eventStream;

  @override
  Stream<SceneInfo> get sceneStream => _sceneController.stream;

  @override
  Stream<UnityLifecycleState> get lifecycleStream => _lifecycle.stateStream;

  /// The internal [MessageHandler] for registering type-specific callbacks.
  MessageHandler get messageHandler => _messageHandler;

  @override
  Future<void> initialize() async {
    _assertNotDisposed();

    _lifecycle.transition(UnityLifecycleState.initializing);
    UnityKitLogger.instance.info('Initializing Unity bridge');

    await _platformSubscription?.cancel();
    _platformSubscription = _platform.events.listen(
      _handlePlatformEvent,
      onError: _handlePlatformError,
    );

    await _platform.initialize();

    UnityKitLogger.instance.debug('Platform initialize() called, '
        'waiting for onUnityCreated event');
  }

  @override
  Future<void> send(UnityMessage message) async {
    _assertNotDisposed();
    _guard.guard();

    await _sendToPlatform(message);
  }

  @override
  Future<void> sendWhenReady(UnityMessage message) async {
    _assertNotDisposed();

    _guard.queueUntilReady(message, _sendToPlatform);
  }

  @override
  Future<void> sendBinary(UnityMessage message) async {
    _assertNotDisposed();
    _guard.guard();

    await _sendBinaryToPlatform(message);
  }

  @override
  Future<void> sendBinaryWhenReady(UnityMessage message) async {
    _assertNotDisposed();

    _guard.queueUntilReady(message, _sendBinaryToPlatform);
  }

  @override
  Future<void> pause() async {
    _assertNotDisposed();

    _lifecycle.transition(UnityLifecycleState.paused);
    await _platform.pause();

    UnityKitLogger.instance.info('Unity player paused');
  }

  @override
  Future<void> resume() async {
    _assertNotDisposed();

    _lifecycle.transition(UnityLifecycleState.resumed);
    await _platform.resume();

    UnityKitLogger.instance.info('Unity player resumed');
  }

  @override
  Future<void> unload() async {
    _assertNotDisposed();

    await _platform.unload();
    _guard.reset();
    _lifecycle.reset();

    UnityKitLogger.instance.info('Unity player unloaded');
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    UnityKitLogger.instance.info('Disposing Unity bridge');

    if (_lifecycle.currentState != UnityLifecycleState.disposed &&
        _lifecycle.currentState != UnityLifecycleState.uninitialized) {
      _lifecycle.transition(UnityLifecycleState.disposed);
    }

    await _platformSubscription?.cancel();
    _platformSubscription = null;

    _batcher?.dispose();
    _throttler?.dispose();
    _guard.dispose();
    _messageHandler.dispose();

    await _messageController.close();
    await _sceneController.close();
    await _performanceController.close();
    _lifecycle.dispose();

    UnityKitLogger.instance.debug('Unity bridge disposed');
  }

  /// Encodes [message] to a binary frame and posts it to the platform.
  ///
  /// Batching/throttling do not apply to the binary path — it is meant for
  /// callers that already control their own send cadence.
  Future<void> _sendBinaryToPlatform(UnityMessage message) async {
    if (_isDisposed) return;

    try {
      final bytes = UnityBinaryCodec.encode(message);
      await _platform.postBinaryMessage(
        message.nativeGameObject,
        UnityMethods.receiveBinary,
        bytes,
      );
      UnityKitLogger.instance.debug(
        'Sent binary: ${message.type} (${bytes.length} bytes)',
      );
    } catch (e, stackTrace) {
      UnityKitLogger.instance.error(
        'Failed to send binary message: ${message.type}',
        e,
        stackTrace,
      );
      throw CommunicationException(
        message: 'Failed to send binary message to Unity',
        target: message.gameObject,
        method: UnityMethods.receiveBinary,
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Sends a message to the platform, optionally through the throttler.
  Future<void> _sendToPlatform(UnityMessage message) async {
    if (_isDisposed) return;

    if (_throttler != null) {
      _throttler.throttle(message, _postToPlatform);
    } else {
      await _postToPlatform(message);
    }
  }

  /// Posts a message directly to the native platform.
  Future<void> _postToPlatform(UnityMessage message) async {
    try {
      await _platform.postMessage(
        message.nativeGameObject,
        message.nativeMethod,
        message.toJson(),
      );
      UnityKitLogger.instance.debug(
        'Sent message: ${message.type} -> ${message.gameObject}',
      );
    } catch (e, stackTrace) {
      UnityKitLogger.instance.error(
        'Failed to send message: ${message.type}',
        e,
        stackTrace,
      );
      throw CommunicationException(
        message: 'Failed to send message to Unity',
        target: message.gameObject,
        method: message.method,
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Handles raw platform events and routes them appropriately.
  void _handlePlatformEvent(Map<String, dynamic> event) {
    if (_isDisposed) return;

    final eventType = event['event'] as String?;
    if (eventType == null) return;

    UnityKitLogger.instance.debug('Platform event: $eventType');

    switch (eventType) {
      case 'onUnityCreated':
        _onUnityCreated();
      case 'onUnityMessage':
        _onUnityMessage(event);
      case 'onUnitySceneLoaded':
        _onUnitySceneLoaded(event);
      case 'onUnityUnloaded':
        _onUnityUnloaded();
      case 'onViewDisposed':
        _onViewDisposed();
      case 'onError':
        _onError(event);
      default:
        UnityKitLogger.instance.debug('Unhandled platform event: $eventType');
    }
  }

  /// Handles platform error events.
  void _handlePlatformError(Object error, StackTrace stackTrace) {
    UnityKitLogger.instance.error(
      'Platform event stream error',
      error,
      stackTrace,
    );
  }

  /// Called when Unity player has been created and is ready.
  void _onUnityCreated() {
    if (_guard.isReady) return; // Already processed, skip duplicate

    _lifecycle.transition(UnityLifecycleState.ready);
    _flushQueuedMessages();
    UnityKitLogger.instance.info('Unity player created and ready');
  }

  /// Marks the guard as ready and flushes queued messages.
  ///
  /// Errors during queue flush are logged but do not propagate,
  /// since this runs inside a platform event callback.
  Future<void> _flushQueuedMessages() async {
    try {
      await _guard.markReady();
    } catch (e, stackTrace) {
      UnityKitLogger.instance.error(
        'Failed to flush queued messages',
        e,
        stackTrace,
      );
    }
  }

  /// Called when a message is received from Unity.
  void _onUnityMessage(Map<String, dynamic> event) {
    final rawData = event['data'];
    if (rawData == null) return;

    try {
      final message = _parseMessage(rawData);

      if (message.type == UnitySignals.performance) {
        _emitPerformance(message);
        return;
      }

      _messageHandler.handle(message);
      _messageController.add(message);
    } catch (e, stackTrace) {
      UnityKitLogger.instance.error(
        'Failed to parse Unity message',
        e,
        stackTrace,
      );
    }
  }

  /// Parses a performance message and forwards it to [performanceStream].
  void _emitPerformance(UnityMessage message) {
    final data = message.data;
    if (data == null) return;

    try {
      _performanceController.add(UnityPerformanceStats.fromMap(data));
    } catch (e, stackTrace) {
      UnityKitLogger.instance.error(
        'Failed to parse performance stats',
        e,
        stackTrace,
      );
    }
  }

  /// Parses raw data from a platform event into a [UnityMessage].
  UnityMessage _parseMessage(Object rawData) {
    if (rawData is String) {
      try {
        return UnityMessage.fromJson(rawData);
      } on FormatException {
        return UnityMessage(type: rawData);
      }
    } else if (rawData is Map) {
      final map = Map<String, dynamic>.from(rawData);
      return UnityMessage(
        type: map['type'] as String? ?? 'unknown',
        data: map['data'] as Map<String, dynamic>?,
      );
    }
    return UnityMessage(type: rawData.toString());
  }

  /// Called when a Unity scene is loaded.
  void _onUnitySceneLoaded(Map<String, dynamic> event) {
    final data = event['data'];
    final SceneInfo sceneInfo;

    if (data is Map) {
      sceneInfo = SceneInfo.fromMap(Map<String, dynamic>.from(data));
    } else if (data is String) {
      sceneInfo = SceneInfo(name: data, isLoaded: true);
    } else {
      sceneInfo = const SceneInfo(name: 'unknown', isLoaded: true);
    }

    _sceneController.add(sceneInfo);
    UnityKitLogger.instance.info('Scene loaded: ${sceneInfo.name}');
  }

  /// Called when the Unity player is unloaded.
  void _onUnityUnloaded() {
    _guard.reset();
    _lifecycle.reset();
    UnityKitLogger.instance.info('Unity player unloaded');
  }

  /// Called when the active platform view was disposed natively.
  ///
  /// The Unity player itself survives (it is a process-wide singleton), but
  /// until a new [UnityView] attaches there is no channel that can deliver
  /// messages — sending would hit a dead channel and throw
  /// `MissingPluginException`. Resetting the readiness guard makes
  /// [sendWhenReady] queue messages until the next `onUnityCreated`, and
  /// [send] throw [EngineNotReadyException] instead.
  void _onViewDisposed() {
    _guard.reset();

    final state = _lifecycle.currentState;
    if (state != UnityLifecycleState.uninitialized &&
        state != UnityLifecycleState.disposed) {
      _lifecycle.reset();
      _lifecycle.transition(UnityLifecycleState.initializing);
    }

    UnityKitLogger.instance.info(
      'Active Unity view disposed — '
      'messages are queued until a new view attaches',
    );
  }

  /// Called when an error event is received from the platform.
  void _onError(Map<String, dynamic> event) {
    final data = event['data'];
    final message = data is Map
        ? (data['message'] as String? ?? 'Unknown error')
        : 'Unknown error';
    UnityKitLogger.instance.error('Unity error: $message');
  }

  /// Asserts the bridge has not been disposed.
  void _assertNotDisposed() {
    if (_isDisposed) {
      throw const BridgeException(
        message: 'Cannot use UnityBridge after dispose()',
      );
    }
  }
}
