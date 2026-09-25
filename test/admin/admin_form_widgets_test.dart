import 'package:facetune/admin/shared/admin_form_widgets.dart';
import 'package:facetune/admin/theme/admin_theme.dart';
import 'package:facetune/admin/theme/admin_tokens.dart';
import 'package:facetune/admin/theme/admin_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpAtWidth(
  WidgetTester tester, {
  required double width,
  required Widget child,
}) async {
  tester.view.physicalSize = Size(width, 900);
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

List<Widget> gridFields() => [
  for (var index = 0; index < 6; index++)
    AdminLabeledField(
      key: Key('field-$index'),
      label: 'Field $index',
      child: const TextField(decoration: InputDecoration()),
    ),
];

void main() {
  testWidgets('labels are visible above controls with canonical helper text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpAtWidth(
      tester,
      width: 360,
      child: const AdminLabeledField(
        label: 'User ID',
        child: TextField(
          decoration: InputDecoration(helperText: 'Exact UUID.'),
        ),
      ),
    );

    expect(find.text('User ID'), findsOneWidget);
    expect(find.text('Exact UUID.'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('User ID')).dy,
      lessThan(tester.getTopLeft(find.byType(TextField)).dy),
    );
    expect(
      tester.widget<Text>(find.text('User ID')).style,
      AdminTypography.formLabel,
    );
    expect(
      Theme.of(
        tester.element(find.byType(TextField)),
      ).inputDecorationTheme.helperStyle,
      AdminTypography.helperText,
    );
    expect(find.bySemanticsLabel(RegExp('User ID')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('text and dropdown controls share geometry and border family', (
    tester,
  ) async {
    await pumpAtWidth(
      tester,
      width: 720,
      child: AdminResponsiveFormGrid(
        children: [
          const AdminLabeledField(
            label: 'Text',
            child: TextField(decoration: InputDecoration()),
          ),
          AdminLabeledField(
            label: 'Dropdown',
            child: DropdownButtonFormField<String>(
              initialValue: 'one',
              decoration: const InputDecoration(),
              items: const [DropdownMenuItem(value: 'one', child: Text('One'))],
              onChanged: (_) {},
            ),
          ),
        ],
      ),
    );

    final theme = Theme.of(tester.element(find.byType(TextField)));
    final border =
        theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
    expect(border.borderRadius, BorderRadius.circular(AdminRadii.control));
    expect(border.borderSide.color, AdminColors.border);
    expect(theme.inputDecorationTheme.constraints?.minHeight, 44);
    expect(tester.getSize(find.byType(TextField)).height, 44);
    expect(
      tester.getSize(find.byType(DropdownButtonFormField<String>)).height,
      44,
    );
    expect(theme.filledButtonTheme.style?.minimumSize?.resolve({})?.height, 44);
  });

  testWidgets('keyboard focus uses the visible accent focus boundary', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await pumpAtWidth(
      tester,
      width: 360,
      child: AdminLabeledField(
        label: 'Focusable field',
        child: TextField(
          key: const Key('focusable-field'),
          focusNode: focusNode,
          decoration: const InputDecoration(),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    final theme = Theme.of(
      tester.element(find.byKey(const Key('focusable-field'))),
    );
    final focused =
        theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder;
    expect(focused.borderSide.color, AdminFocus.ringColor);
    expect(focused.borderSide.width, AdminFocus.ringWidth);
  });

  testWidgets(
    'responsive grid uses deliberate four, two, and one-column rows',
    (tester) async {
      Future<void> verify(double width, int columns) async {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(
          MaterialApp(
            theme: AdminTheme.dark,
            home: Scaffold(
              body: SizedBox(
                width: width,
                child: AdminResponsiveFormGrid(children: gridFields()),
              ),
            ),
          ),
        );
        await tester.pump();

        final firstTop = tester.getTopLeft(find.byKey(const Key('field-0'))).dy;
        for (var index = 1; index < columns; index++) {
          expect(
            tester.getTopLeft(find.byKey(Key('field-$index'))).dy,
            firstTop,
            reason: '$width px should place field $index in the first row',
          );
        }
        if (columns < 6) {
          expect(
            tester.getTopLeft(find.byKey(Key('field-$columns'))).dy,
            greaterThan(firstTop),
          );
        }
        expect(tester.takeException(), isNull);
      }

      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await verify(1200, 4);
      await verify(800, 2);
      await verify(520, 1);
    },
  );
}
