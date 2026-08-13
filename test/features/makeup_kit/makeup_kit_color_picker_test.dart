import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/makeup_kit/domain/value_objects/normalized_hex_color.dart';
import 'package:facetune/features/makeup_kit/presentation/utils/makeup_kit_curated_shades.dart';
import 'package:facetune/features/makeup_kit/presentation/widgets/makeup_kit_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Harness extends StatefulWidget {
  const _Harness({required this.category, required this.initial});

  final MakeupKitCategory category;
  final CuratedShade initial;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late NormalizedHexColor color = widget.initial.color;
  late String? label = widget.initial.label;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: MakeupKitColorPicker(
        category: widget.category,
        selectedColor: color,
        selectedLabel: label,
        onColorSelected: (newColor, newLabel) => setState(() {
          color = newColor;
          label = newLabel;
        }),
      ),
    ),
  );
}

void main() {
  testWidgets('starts on the initial curated shade', (tester) async {
    final shades = MakeupKitCuratedShades.forCategory(
      MakeupKitCategory.lipstick,
    );
    await tester.pumpWidget(
      _Harness(category: MakeupKitCategory.lipstick, initial: shades.first),
    );

    expect(find.text('Selected: ${shades.first.label}'), findsOneWidget);
  });

  testWidgets('tapping a different curated shade updates the selection', (
    tester,
  ) async {
    final shades = MakeupKitCuratedShades.forCategory(
      MakeupKitCategory.lipstick,
    );
    await tester.pumpWidget(
      _Harness(category: MakeupKitCategory.lipstick, initial: shades.first),
    );

    await tester.tap(find.text(shades[1].label));
    await tester.pumpAndSettle();

    expect(find.text('Selected: ${shades[1].label}'), findsOneWidget);
  });

  testWidgets('a valid HEX entry updates the color and clears the label', (
    tester,
  ) async {
    final shades = MakeupKitCuratedShades.forCategory(
      MakeupKitCategory.lipstick,
    );
    await tester.pumpWidget(
      _Harness(category: MakeupKitCategory.lipstick, initial: shades.first),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Advanced: HEX reference'),
      'AABBCC',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Selected: #AABBCC'), findsOneWidget);
    expect(find.text('Enter a valid 6-digit HEX color.'), findsNothing);
  });

  testWidgets(
    'an invalid HEX entry is rejected and does not change the color',
    (tester) async {
      final shades = MakeupKitCuratedShades.forCategory(
        MakeupKitCategory.lipstick,
      );
      await tester.pumpWidget(
        _Harness(category: MakeupKitCategory.lipstick, initial: shades.first),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Advanced: HEX reference'),
        'ZZZZZZ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid 6-digit HEX color.'), findsOneWidget);
      expect(find.text('Selected: ${shades.first.label}'), findsOneWidget);
    },
  );

  testWidgets('dragging the hue slider selects a custom color', (tester) async {
    final shades = MakeupKitCuratedShades.forCategory(
      MakeupKitCategory.lipstick,
    );
    await tester.pumpWidget(
      _Harness(category: MakeupKitCategory.lipstick, initial: shades.first),
    );

    await tester.drag(find.byType(Slider).first, const Offset(120, 0));
    await tester.pumpAndSettle();

    expect(find.text('Selected: ${shades.first.label}'), findsNothing);
    expect(find.textContaining('Selected: #'), findsOneWidget);
  });

  testWidgets('offers curated shades specific to the category', (tester) async {
    final shades = MakeupKitCuratedShades.forCategory(
      MakeupKitCategory.eyeliner,
    );
    await tester.pumpWidget(
      _Harness(category: MakeupKitCategory.eyeliner, initial: shades.first),
    );

    for (final shade in shades) {
      expect(find.text(shade.label), findsOneWidget);
    }
  });
}
