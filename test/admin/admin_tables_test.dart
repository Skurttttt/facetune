import 'package:facetune/admin/shared/admin_list_widgets.dart';
import 'package:facetune/admin/theme/admin_theme.dart';
import 'package:facetune/admin/theme/admin_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpTable(
  WidgetTester tester, {
  required Widget child,
  double width = 420,
}) async {
  tester.view.physicalSize = Size(width, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AdminTheme.dark,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('operational table uses the canonical contained dimensions', (
    tester,
  ) async {
    await pumpTable(
      tester,
      child: AdminTable(
        columns: const [
          DataColumn(label: Text('User')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Actions')),
        ],
        rows: const [
          DataRow(
            cells: [
              DataCell(Text('member@example.invalid')),
              DataCell(Text('Active')),
              DataCell(Text('View details')),
            ],
          ),
        ],
      ),
    );

    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.headingRowHeight, 44);
    expect(table.dataRowMinHeight, 52);
    expect(table.dataRowMaxHeight, 64);
    expect(table.horizontalMargin, AdminSpacing.md);
    expect(table.columnSpacing, AdminSpacing.xl);
    expect(table.dividerThickness, AdminBorders.hairline);

    final surface = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(AdminTable),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = surface.decoration as BoxDecoration;
    final border = decoration.border! as Border;
    expect(decoration.color, AdminColors.surface);
    expect(decoration.borderRadius, BorderRadius.circular(AdminRadii.card));
    expect(border.left.width, AdminBorders.hairline);
    expect(border.left.color, AdminColors.border);

    final scroll = find.descendant(
      of: find.byType(AdminTable),
      matching: find.byType(SingleChildScrollView),
    );
    expect(scroll, findsOneWidget);
    expect(tester.getSize(find.byType(AdminTable)).width, 420);
    expect(tester.getSize(scroll).width, 420);
    expect(tester.takeException(), isNull);
  });

  testWidgets('horizontal scroll keeps the rightmost action reachable', (
    tester,
  ) async {
    const actionKey = Key('rightmost-table-action');
    await pumpTable(
      tester,
      // 768px browser width minus the supported compact sidebar and page
      // insets: this reproduces the smallest supported table region.
      width: 656,
      child: AdminTable(
        columns: const [
          DataColumn(label: Text('Very wide identity column')),
          DataColumn(label: Text('Very wide operational status')),
          DataColumn(label: Text('Very wide metadata column')),
          DataColumn(label: Text('Actions')),
        ],
        rows: [
          DataRow(
            cells: [
              const DataCell(Text('member-with-a-long-name@example.invalid')),
              const DataCell(Text('Pending administrative review')),
              const DataCell(Text('Long metadata that remains in the table')),
              DataCell(
                AdminTableActions(
                  children: [
                    TextButton(
                      key: actionKey,
                      onPressed: () {},
                      child: const Text('Open'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    expect(find.byKey(actionKey).hitTestable(), findsNothing);
    final scroll = find.descendant(
      of: find.byType(AdminTable),
      matching: find.byType(SingleChildScrollView),
    );
    await tester.drag(scroll, const Offset(-1600, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(actionKey).hitTestable(), findsOneWidget);
    expect(tester.getSize(find.byType(AdminTable)).width, 656);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty result remains inside the operational table surface', (
    tester,
  ) async {
    const emptyKey = Key('table-empty-state');
    await pumpTable(
      tester,
      child: const AdminTable(
        columns: [
          DataColumn(label: Text('Created')),
          DataColumn(label: Text('Action')),
        ],
        rows: [],
        emptyState: Padding(
          key: emptyKey,
          padding: EdgeInsets.all(AdminSpacing.lg),
          child: Text('No matching records'),
        ),
      ),
    );

    expect(find.byType(DataTable), findsOneWidget);
    expect(find.byKey(emptyKey), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(emptyKey),
        matching: find.byType(AdminTable),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'identity shortens only the visual UUID and retains the full ID',
    (tester) async {
      const id = '12345678-1234-4234-8234-123456789abc';
      await pumpTable(
        tester,
        child: const AdminIdentityCell(
          email: 'member@example.invalid',
          userId: id,
        ),
      );

      expect(find.text('member@example.invalid'), findsOneWidget);
      expect(find.text('12345678…9abc'), findsOneWidget);
      expect(tester.widget<Tooltip>(find.byType(Tooltip).last).message, id);
    },
  );

  testWidgets('status badge exposes text semantics and a semantic indicator', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpTable(
      tester,
      child: const AdminStatusBadge(
        label: 'Active',
        semanticsPrefix: 'Account status',
        emphasis: AdminBadgeEmphasis.positive,
      ),
    );

    expect(find.bySemanticsLabel('Account status: Active'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    final indicator = tester.widget<Container>(
      find.byKey(const Key('admin-status-indicator')),
    );
    final decoration = indicator.decoration! as BoxDecoration;
    expect(decoration.color, AdminColors.success);
    expect(decoration.color, isNot(AdminColors.accent));
    semantics.dispose();
  });

  testWidgets('pagination wraps without changing control availability', (
    tester,
  ) async {
    var previous = 0;
    var next = 0;
    await pumpTable(
      tester,
      width: 300,
      child: AdminPaginationControl(
        keyPrefix: 'test',
        pageNumber: 2,
        itemCount: 7,
        pageSize: 25,
        canGoBack: true,
        canGoNext: false,
        onPrevious: () async => previous++,
        onNext: () async => next++,
      ),
    );

    expect(find.text('Page 2 · 7 of up to 25'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('test-next'))).enabled,
      isFalse,
    );
    await tester.tap(find.byKey(const Key('test-previous')));
    expect(previous, 1);
    expect(next, 0);
    expect(tester.takeException(), isNull);
  });
}
