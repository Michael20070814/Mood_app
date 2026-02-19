import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mood_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EmotionApp());

    // Verify that the app title is displayed
    expect(find.text('情绪盒子'), findsOneWidget);

    // Verify that emotion cards are displayed
    expect(find.text('开心'), findsOneWidget);
    expect(find.text('幸福'), findsOneWidget);
  });
}
