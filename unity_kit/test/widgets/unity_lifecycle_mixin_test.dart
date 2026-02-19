import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:unity_kit/src/bridge/unity_bridge.dart';
import 'package:unity_kit/src/widgets/unity_lifecycle_mixin.dart';

class MockUnityBridge extends Mock implements UnityBridge {}

/// Test widget that uses [UnityLifecycleMixin].
class _TestWidget extends StatefulWidget {
  const _TestWidget({required this.bridge});

  final UnityBridge bridge;

  @override
  State<_TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends State<_TestWidget>
    with WidgetsBindingObserver, UnityLifecycleMixin<_TestWidget> {
  @override
  UnityBridge get bridge => widget.bridge;

  @override
  void initState() {
    super.initState();
    initLifecycle();
  }

  @override
  void dispose() {
    disposeLifecycle();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

void main() {
  late MockUnityBridge mockBridge;

  setUp(() {
    mockBridge = MockUnityBridge();
    when(() => mockBridge.pause()).thenAnswer((_) async {});
    when(() => mockBridge.resume()).thenAnswer((_) async {});
  });

  Widget buildApp(UnityBridge bridge) {
    return WidgetsApp(
      color: const Color(0x00000000),
      builder: (_, __) => _TestWidget(bridge: bridge),
    );
  }

  group('UnityLifecycleMixin', () {
    testWidgets('initLifecycle registers observer', (tester) async {
      await tester.pumpWidget(buildApp(mockBridge));

      // The observer is registered, so it should be among the binding observers.
      // Simulate a lifecycle change to verify it is listening.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      verify(() => mockBridge.pause()).called(1);
    });

    testWidgets('disposeLifecycle unregisters observer', (tester) async {
      await tester.pumpWidget(buildApp(mockBridge));

      // Remove the widget (triggers dispose -> disposeLifecycle).
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0x00000000),
          builder: (_, __) => const SizedBox.shrink(),
        ),
      );

      // Now lifecycle events should not reach the mixin.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      verifyNever(() => mockBridge.pause());
    });

    testWidgets('paused state calls bridge.pause()', (tester) async {
      await tester.pumpWidget(buildApp(mockBridge));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      verify(() => mockBridge.pause()).called(1);
      verifyNever(() => mockBridge.resume());
    });

    testWidgets('resumed state calls bridge.resume()', (tester) async {
      await tester.pumpWidget(buildApp(mockBridge));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      verify(() => mockBridge.resume()).called(1);
      verifyNever(() => mockBridge.pause());
    });

    testWidgets('other lifecycle states do not call pause or resume',
        (tester) async {
      await tester.pumpWidget(buildApp(mockBridge));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      await tester.pump();

      verifyNever(() => mockBridge.pause());
      verifyNever(() => mockBridge.resume());
    });
  });
}
