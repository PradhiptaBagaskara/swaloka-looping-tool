// Basic Flutter widget test for Swaloka Looping Tool

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swaloka_looping_tool/app.dart';

void main() {
  testWidgets('App launches successfully and shows landing page', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: SwalokaApp()));

    // Verify that the app brand name is present
    expect(find.text('SWALOKA LOOPING TOOL'), findsOneWidget);

    // Verify that landing page cards are present
    expect(find.text('New Project'), findsOneWidget);
    expect(find.text('Open Project'), findsOneWidget);
  });
}
