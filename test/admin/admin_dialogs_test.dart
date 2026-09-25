import 'package:facetune/admin/shared/admin_dialogs.dart';
import 'package:facetune/admin/theme/admin_theme.dart';
import 'package:facetune/admin/theme/admin_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _cancelKey = Key('test-dialog-cancel');
const _confirmKey = Key('test-dialog-confirm');

Future<void> pumpDialogHarness(
  WidgetTester tester, {
  required VoidCallback onCancel,
  required VoidCallback onConfirm,
  bool destructive = false,
  Size size = const Size(520, 700),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AdminTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              key: const Key('open-test-dialog'),
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (dialogContext) => AdminConfirmationDialog(
                  title: destructive ? 'Revoke access?' : 'Review change',
                  description: 'Confirm the frozen operational intent.',
                  confirmLabel: destructive ? 'Revoke access' : 'Confirm',
                  confirmButtonKey: _confirmKey,
                  cancelButtonKey: _cancelKey,
                  destructive: destructive,
                  onCancel: () {
                    onCancel();
                    Navigator.of(dialogContext).pop();
                  },
                  onConfirm: () {
                    onConfirm();
                    Navigator.of(dialogContext).pop();
                  },
                  content: const AdminDialogDetailRows(
                    rows: [
                      ('Account', 'pilot@example.invalid'),
                      (
                        'Entitlement ID',
                        '11111111-2222-4333-8444-555555555555',
                      ),
                      ('Reason', 'Panel review completed'),
                    ],
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-test-dialog')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dialog uses canonical bounds, padding, radius, and error role', (
    tester,
  ) async {
    await pumpDialogHarness(
      tester,
      destructive: true,
      onCancel: () {},
      onConfirm: () {},
    );

    final frame = tester.getSize(
      find.byKey(const Key('admin-confirmation-dialog-frame')),
    );
    expect(frame.width, lessThanOrEqualTo(520 - (AdminSpacing.lg * 2)));
    expect(frame.height, lessThanOrEqualTo(700 - (AdminSpacing.lg * 2)));

    final padding = tester.widget<Padding>(
      find.byKey(const Key('admin-confirmation-dialog-padding')),
    );
    expect(padding.padding, const EdgeInsets.all(AdminSpacing.lg));

    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    final shape = dialog.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(AdminRadii.dialog));
    expect(
      shape.side.color,
      Theme.of(tester.element(find.byKey(_confirmKey))).colorScheme.error,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(_confirmKey))
          .style
          ?.backgroundColor
          ?.resolve({}),
      Theme.of(tester.element(find.byKey(_confirmKey))).colorScheme.error,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('safe keyboard order focuses Cancel before confirm', (
    tester,
  ) async {
    var cancelled = 0;
    var confirmed = 0;
    await pumpDialogHarness(
      tester,
      onCancel: () => cancelled++,
      onConfirm: () => confirmed++,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(cancelled, 1);
    expect(confirmed, 0);

    await tester.tap(find.byKey(const Key('open-test-dialog')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(cancelled, 1);
    expect(confirmed, 1);
  });
}
