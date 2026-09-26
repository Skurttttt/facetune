import 'package:facetune/admin/shared/admin_list_widgets.dart';
import 'package:facetune/admin/theme/admin_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpState(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: AdminTheme.dark,
    home: Scaffold(
      body: Center(child: SizedBox(width: 700, child: child)),
    ),
  ),
);

void main() {
  testWidgets('read loading uses deliberate skeleton rows without a spinner', (
    tester,
  ) async {
    await pumpState(
      tester,
      const AdminListLoadingRow(
        key: Key('state-loading'),
        label: 'Loading records',
      ),
    );

    expect(find.byType(AdminSkeletonRows), findsOneWidget);
    expect(find.text('Loading records'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets(
    'state panels expose title, explanation, action, and error role',
    (tester) async {
      var retries = 0;
      await pumpState(
        tester,
        AdminListNotice(
          key: const Key('state-error'),
          icon: Icons.error_outline,
          title: 'Records could not be loaded',
          message: 'The list is temporarily unavailable.',
          error: true,
          action: TextButton(
            onPressed: () => retries++,
            child: const Text('Try again'),
          ),
        ),
      );

      expect(find.text('Records could not be loaded'), findsOneWidget);
      expect(find.text('The list is temporarily unavailable.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retries, 1);

      final panel = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byKey(const Key('state-error')),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = panel.decoration as BoxDecoration;
      expect(
        decoration.border?.top.color,
        Theme.of(
          tester.element(find.byKey(const Key('state-error'))),
        ).colorScheme.error,
      );
    },
  );

  testWidgets('mutation progress is explicit and does not mimic read data', (
    tester,
  ) async {
    await pumpState(
      tester,
      const AdminListLoadingRow(label: 'Applying change', skeleton: false),
    );

    expect(find.byType(AdminProgressState), findsOneWidget);
    expect(find.text('Applying change'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(AdminSkeletonRows), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
