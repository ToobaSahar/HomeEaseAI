// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:day35/pages/start.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Import the main.dart file

void main() {
  // Smoke test for StartPage
  testWidgets('StartPage smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: StartPage(),
    ));
    expect(find.byType(StartPage), findsOneWidget);
  });

  // Counter increment test (as in your original test)
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build your app and trigger a frame.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(child: Text('0')),
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          child: Icon(Icons.add),
        ),
      ),
    ));

    // Verify that the counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify the counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
