import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zitakimmo_v2/app.dart'; // Vérifiez le nom du package dans pubspec.yaml

void main() {
  testWidgets('Application démarre sans erreur', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(Scaffold), findsOneWidget);
  });
}