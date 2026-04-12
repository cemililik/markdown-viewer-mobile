import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/app/app.dart';

void main() {
  group('MarkdownViewerApp', () {
    testWidgets('should boot and render the library empty state', (
      tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: MarkdownViewerApp()));
      await tester.pumpAndSettle();

      // The default test locale is en_US, so we should see the English copy.
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('No documents yet'), findsOneWidget);
    });
  });
}
