import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit_example/main.dart';

void main() {
  testWidgets('App renders the Unity Kit shell with feature controls',
      (WidgetTester tester) async {
    await tester.pumpWidget(const UnityKitExampleApp());
    await tester.pump();

    // AppBar title.
    expect(find.text('Unity Kit'), findsOneWidget);

    // Status chip starts in the loading state (Unity not ready in tests).
    expect(find.text('loading'), findsOneWidget);

    // 2.0.0 feature controls are present.
    expect(find.byTooltip('AR mode'), findsOneWidget);
    expect(find.byTooltip('Reset all'), findsOneWidget);
  });

  testWidgets('AR mode menu lists every UnityArMode', (WidgetTester tester) async {
    await tester.pumpWidget(const UnityKitExampleApp());
    await tester.pump();

    await tester.tap(find.byTooltip('AR mode'));
    // Fixed pumps instead of pumpAndSettle: the embedded platform view keeps
    // a pending frame, so the tree never fully settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('AR: none'), findsOneWidget);
    expect(find.text('AR: passthrough'), findsOneWidget);
    expect(find.text('AR: overlay'), findsOneWidget);
  });
}
