import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/widgets/unity_placeholder.dart';

void main() {
  Widget buildApp({required Widget child}) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('UnityPlaceholder', () {
    testWidgets('renders default indicator and message', (tester) async {
      await tester.pumpWidget(buildApp(child: const UnityPlaceholder()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading Unity...'), findsOneWidget);
    });

    testWidgets('renders custom message', (tester) async {
      await tester.pumpWidget(
        buildApp(child: const UnityPlaceholder(message: 'Please wait...')),
      );

      expect(find.text('Please wait...'), findsOneWidget);
      expect(find.text('Loading Unity...'), findsNothing);
    });

    testWidgets('applies custom background color', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: const UnityPlaceholder(backgroundColor: Colors.black),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      expect(container.color, Colors.black);
    });

    testWidgets('applies custom indicator color', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: const UnityPlaceholder(indicatorColor: Colors.red),
        ),
      );

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.color, Colors.red);
    });

    testWidgets('uses custom builder when provided', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: UnityPlaceholder(
            builder: (_) => const Text('Custom loading'),
          ),
        ),
      );

      expect(find.text('Custom loading'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('custom builder ignores message and indicatorColor',
        (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: UnityPlaceholder(
            message: 'Ignored',
            indicatorColor: Colors.green,
            textStyle: const TextStyle(fontSize: 99),
            builder: (_) => const Text('Builder wins'),
          ),
        ),
      );

      expect(find.text('Builder wins'), findsOneWidget);
      expect(find.text('Ignored'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
