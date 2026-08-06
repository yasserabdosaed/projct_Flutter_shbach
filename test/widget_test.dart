import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shabakat_app/app.dart';
import 'package:shabakat_app/providers/app_provider.dart';

void main() {
  testWidgets('App builds without error', (WidgetTester tester) async {
    final provider = AppProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const ShabakatApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
