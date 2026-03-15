// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';

void main() {
  testWidgets('Home screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PartyMiniGamesApp());

    // Verify that our counter starts at 0.
    expect(find.text('파티 미니게임'), findsOneWidget);
    expect(find.text('로비 입장'), findsOneWidget);
    expect(find.text('닉네임 입력'), findsOneWidget);

    // Tap the '+' icon and trigger a frame.

    // Verify that our counter has incremented.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
