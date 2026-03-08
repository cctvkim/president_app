// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:president_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MyApp(initialFontScale: 1.0), // ✅ 추가
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
