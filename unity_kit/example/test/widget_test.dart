import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit_example/main.dart';

void main() {
  testWidgets('App renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const UnityKitExampleApp());

    expect(find.text('Unity Kit Example'), findsOneWidget);
    expect(find.text('Load Scene'), findsOneWidget);
    expect(find.text('Query State'), findsOneWidget);
    expect(find.text('Trigger Action'), findsOneWidget);
    expect(find.text('Message Log'), findsOneWidget);
  });
}
