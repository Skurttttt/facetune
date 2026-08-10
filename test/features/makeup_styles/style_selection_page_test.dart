import 'package:facetune/features/makeup_styles/presentation/pages/style_selection_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selects and confirms a style without leaving the page', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: StyleSelectionPage())),
    );

    expect(find.text('Select a style to continue'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Natural makeup style. Fresh skin, soft definition, and effortless polish.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Natural'));
    await tester.pumpAndSettle();
    expect(find.text('Continue with Natural'), findsOneWidget);

    await tester.tap(find.text('Continue with Natural'));
    await tester.pumpAndSettle();

    expect(find.text('Natural selected'), findsOneWidget);
    expect(
      find.textContaining('Natural is saved for this scan'),
      findsOneWidget,
    );
    expect(find.byType(StyleSelectionPage), findsOneWidget);
  });
}
