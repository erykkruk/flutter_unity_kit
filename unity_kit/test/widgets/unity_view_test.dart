import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/bridge/unity_bridge.dart';
import 'package:unity_kit/src/models/models.dart';
import 'package:unity_kit/src/widgets/unity_view.dart';

/// Mock bridge with [StreamController]s for verifying widget behavior.
class MockUnityBridge implements UnityBridge {
  final StreamController<UnityMessage> _messageController =
      StreamController<UnityMessage>.broadcast();
  final StreamController<UnityEvent> _eventController =
      StreamController<UnityEvent>.broadcast();
  final StreamController<SceneInfo> _sceneController =
      StreamController<SceneInfo>.broadcast();
  final StreamController<UnityLifecycleState> _lifecycleController =
      StreamController<UnityLifecycleState>.broadcast();

  bool initializeCalled = false;
  bool pauseCalled = false;
  bool resumeCalled = false;
  bool unloadCalled = false;
  bool disposeCalled = false;

  UnityLifecycleState _currentState = UnityLifecycleState.uninitialized;

  @override
  UnityLifecycleState get currentState => _currentState;

  @override
  bool get isReady => _currentState == UnityLifecycleState.ready;

  @override
  Stream<UnityMessage> get messageStream => _messageController.stream;

  @override
  Stream<UnityEvent> get eventStream => _eventController.stream;

  @override
  Stream<SceneInfo> get sceneStream => _sceneController.stream;

  @override
  Stream<UnityLifecycleState> get lifecycleStream =>
      _lifecycleController.stream;

  @override
  Future<void> initialize() async {
    initializeCalled = true;
    _currentState = UnityLifecycleState.initializing;
  }

  @override
  Future<void> send(UnityMessage message) async {}

  @override
  Future<void> sendWhenReady(UnityMessage message) async {}

  @override
  Future<void> pause() async {
    pauseCalled = true;
  }

  @override
  Future<void> resume() async {
    resumeCalled = true;
  }

  @override
  Future<void> unload() async {
    unloadCalled = true;
  }

  @override
  Future<void> dispose() async {
    disposeCalled = true;
  }

  /// Simulate the bridge becoming ready.
  void emitReady() {
    _currentState = UnityLifecycleState.ready;
    _lifecycleController.add(UnityLifecycleState.ready);
  }

  /// Simulate receiving a message from Unity.
  void emitMessage(UnityMessage message) {
    _messageController.add(message);
  }

  /// Simulate an event from the Unity player.
  void emitEvent(UnityEvent event) {
    _eventController.add(event);
  }

  /// Simulate a scene being loaded.
  void emitSceneLoaded(SceneInfo scene) {
    _sceneController.add(scene);
  }

  /// Close all stream controllers.
  Future<void> closeStreams() async {
    await _messageController.close();
    await _eventController.close();
    await _sceneController.close();
    await _lifecycleController.close();
  }
}

void main() {
  group('UnityView', () {
    late MockUnityBridge mockBridge;

    setUp(() {
      mockBridge = MockUnityBridge();
    });

    tearDown(() async {
      await mockBridge.closeStreams();
    });

    testWidgets('creates with default config', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: UnityView(bridge: mockBridge),
        ),
      );

      expect(find.byType(UnityView), findsOneWidget);
      expect(find.byType(Stack), findsOneWidget);
    });

    testWidgets(
      'renders platform-not-supported on unsupported platform',
      variant: const TargetPlatformVariant({TargetPlatform.linux}),
      (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: UnityView(bridge: mockBridge),
          ),
        );

        expect(find.text('Platform not supported'), findsOneWidget);
      },
    );

    testWidgets('uses external bridge when provided', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: UnityView(bridge: mockBridge),
        ),
      );

      expect(mockBridge.initializeCalled, isFalse);
    });

    testWidgets('calls onReady when bridge becomes ready', (tester) async {
      UnityBridge? readyBridge;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: UnityView(
            bridge: mockBridge,
            onReady: (bridge) => readyBridge = bridge,
          ),
        ),
      );

      expect(readyBridge, isNull);

      mockBridge.emitReady();
      await tester.pump();

      expect(readyBridge, same(mockBridge));
    });

    testWidgets('calls onMessage when message received', (tester) async {
      final receivedMessages = <UnityMessage>[];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: UnityView(
            bridge: mockBridge,
            onMessage: receivedMessages.add,
          ),
        ),
      );

      final message = UnityMessage.command('TestAction');
      mockBridge.emitMessage(message);
      await tester.pump();

      expect(receivedMessages, hasLength(1));
      expect(receivedMessages.first.type, 'TestAction');
    });

    testWidgets('calls onEvent when event received', (tester) async {
      final receivedEvents = <UnityEvent>[];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: UnityView(
            bridge: mockBridge,
            onEvent: receivedEvents.add,
          ),
        ),
      );

      final event = UnityEvent.created();
      mockBridge.emitEvent(event);
      await tester.pump();

      expect(receivedEvents, hasLength(1));
      expect(receivedEvents.first.type, UnityEventType.created);
    });

    testWidgets('calls onSceneLoaded when scene loaded', (tester) async {
      final loadedScenes = <SceneInfo>[];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: UnityView(
            bridge: mockBridge,
            onSceneLoaded: loadedScenes.add,
          ),
        ),
      );

      const scene = SceneInfo(name: 'Level1', buildIndex: 0, isLoaded: true);
      mockBridge.emitSceneLoaded(scene);
      await tester.pump();

      expect(loadedScenes, hasLength(1));
      expect(loadedScenes.first.name, 'Level1');
    });

    testWidgets(
      'shows placeholder when not ready',
      variant: const TargetPlatformVariant({TargetPlatform.linux}),
      (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: UnityView(
              bridge: mockBridge,
              placeholder: const Text('Loading Unity...'),
            ),
          ),
        );

        expect(find.text('Loading Unity...'), findsOneWidget);
      },
    );

    testWidgets(
      'hides placeholder when ready',
      variant: const TargetPlatformVariant({TargetPlatform.linux}),
      (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: UnityView(
              bridge: mockBridge,
              placeholder: const Text('Loading Unity...'),
            ),
          ),
        );

        expect(find.text('Loading Unity...'), findsOneWidget);

        mockBridge.emitReady();
        await tester.pumpAndSettle();

        expect(find.text('Loading Unity...'), findsNothing);
      },
    );

    testWidgets('does NOT dispose external bridge on widget dispose',
        (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: UnityView(bridge: mockBridge),
        ),
      );

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.shrink(),
        ),
      );

      expect(mockBridge.disposeCalled, isFalse);
    });

    testWidgets('cancels subscriptions on dispose', (tester) async {
      final receivedMessages = <UnityMessage>[];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: UnityView(
            bridge: mockBridge,
            onMessage: receivedMessages.add,
          ),
        ),
      );

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.shrink(),
        ),
      );

      mockBridge.emitMessage(UnityMessage.command('AfterDispose'));
      await tester.pump();

      expect(receivedMessages, isEmpty);
    });

    testWidgets('onReady fires only once for multiple ready events',
        (tester) async {
      var readyCount = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: UnityView(
            bridge: mockBridge,
            onReady: (_) => readyCount++,
          ),
        ),
      );

      mockBridge.emitReady();
      await tester.pump();

      mockBridge.emitReady();
      await tester.pump();

      expect(readyCount, 1);
    });

    testWidgets(
      'renders without placeholder when none provided',
      variant: const TargetPlatformVariant({TargetPlatform.linux}),
      (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: UnityView(bridge: mockBridge),
          ),
        );

        expect(find.byType(Stack), findsOneWidget);
        expect(find.text('Loading Unity...'), findsNothing);
        expect(find.text('Platform not supported'), findsOneWidget);
      },
    );
  });
}
