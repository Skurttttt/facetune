import 'dart:async';

import 'package:facetune/features/custom_palette/domain/catalog/custom_palette_catalog.dart';
import 'package:facetune/features/custom_palette/domain/catalog/custom_palette_color_model.dart';
import 'package:facetune/features/custom_palette/domain/repositories/custom_palette_gateway.dart';
import 'package:facetune/features/custom_palette/domain/validation/custom_palette_contract.dart';
import 'package:facetune/features/custom_palette/presentation/controllers/custom_palette_draft_controller.dart';
import 'package:facetune/features/custom_palette/presentation/controllers/custom_palette_draft_state.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_finish.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/custom_palette_fixture.dart';

const _blush = MakeupKitCategory.blush;
const _lipstick = MakeupKitCategory.lipstick;

CustomPaletteSwatch _swatch(String label) =>
    CustomPaletteCatalog.swatches.firstWhere((s) => s.label == label);

void main() {
  late FakePaletteGateway gateway;
  late CustomPaletteDraftController controller;
  late int issued;

  setUp(() {
    gateway = FakePaletteGateway();
    issued = 0;
    controller = CustomPaletteDraftController(
      gateway,
      newId: () => 'request-${++issued}',
    )..prepareFor(analysisId: 'analysis-1', styleCode: 'soft_glam');
  });

  tearDown(() => controller.dispose());

  void completeBlush() {
    controller
      ..selectSwatch(_blush, _swatch('Red'))
      ..selectFinish(_blush, MakeupKitFinish.matte);
  }

  test('starts empty and invalid', () {
    expect(controller.state.enabledCategories, isEmpty);
    expect(
      controller.state.issues.single.code,
      CustomPaletteIssueCode.paletteEmpty,
    );
  });

  test('choosing a color enables the category and starts from that color', () {
    controller.selectSwatch(_blush, _swatch('Red'));
    final selection = controller.state.selectionFor(_blush);
    expect(selection.enabled, isTrue);
    expect(selection.adjustedColor?.value, '#C8102E');
    expect(selection.isAdjusted, isFalse);
    expect(selection.colorName, 'Red');
    expect(
      controller.state.issues.single.code,
      CustomPaletteIssueCode.selectionIncomplete,
    );
  });

  test('adjusting changes the final color and keeps the base', () {
    completeBlush();
    controller.setLightness(_blush, 80);
    final selection = controller.state.selectionFor(_blush);
    final position = CustomPaletteColorModel.toHsl(_swatch('Red').color);
    expect(selection.base?.hex, '#C8102E');
    expect(
      selection.adjustedColor,
      CustomPaletteColorModel.adjust(
        _swatch('Red').color,
        saturation: position.saturation,
        lightness: 80,
      ),
    );
    expect(selection.colorName, 'Red, adjusted');
    expect(controller.state.isValid, isTrue);
  });

  test('reset returns to the exact base color', () {
    completeBlush();
    controller
      ..setLightness(_blush, 80)
      ..setSaturation(_blush, 10)
      ..resetAdjustment(_blush);
    final selection = controller.state.selectionFor(_blush);
    expect(selection.adjustedColor?.value, '#C8102E');
    expect(selection.isAdjusted, isFalse);
  });

  test('adjusting before a color is chosen does nothing', () {
    controller
      ..setLightness(_blush, 80)
      ..setSaturation(_blush, 80);
    expect(controller.state.selectionFor(_blush).enabled, isFalse);
    expect(controller.state.selectionFor(_blush).adjustedColor, isNull);
  });

  test('refuses a finish the category does not allow', () {
    controller.selectSwatch(_blush, _swatch('Red'));
    controller.selectFinish(_blush, MakeupKitFinish.glossy);
    expect(controller.state.selectionFor(_blush).finish, isNull);
  });

  test('a disabled category keeps its values but is not sent', () {
    completeBlush();
    controller.setEnabled(_blush, enabled: false);
    expect(controller.state.inputs, isEmpty);
    expect(controller.state.selectionFor(_blush).base?.label, 'Red');
    controller.setEnabled(_blush, enabled: true);
    expect(controller.state.isValid, isTrue);
  });

  test('the same analysis and style keep the draft; another resets it', () {
    completeBlush();
    controller.prepareFor(analysisId: 'analysis-1', styleCode: 'soft_glam');
    expect(controller.state.selectionFor(_blush).base?.label, 'Red');
    controller.prepareFor(analysisId: 'analysis-1', styleCode: 'bridal');
    expect(controller.state.selectionFor(_blush).base, isNull);
    completeBlush();
    controller.prepareFor(analysisId: 'analysis-2', styleCode: 'bridal');
    expect(controller.state.selectionFor(_blush).base, isNull);
  });

  group('generate', () {
    test('does nothing while the draft is invalid', () async {
      await controller.generate();
      controller.selectSwatch(_blush, _swatch('Red'));
      await controller.generate();
      expect(gateway.requests, isEmpty);
    });

    test('emits the canonical payload in canonical order', () async {
      controller
        ..selectSwatch(_lipstick, _swatch('Berry'))
        ..selectFinish(_lipstick, MakeupKitFinish.glossy);
      completeBlush();
      controller.setLightness(_blush, 80);
      await controller.generate();

      final red = CustomPaletteColorModel.toHsl(_swatch('Red').color);
      expect(gateway.requests.single.toJson(), {
        'paletteRequestId': 'request-1',
        'paletteVersion': 'custom_color_palette_contract_v1',
        'sourceMode': 'custom_color_palette',
        'analysisId': 'analysis-1',
        'style': 'soft_glam',
        'derivedFromPaletteId': null,
        'categorySelections': [
          {
            'categoryCode': 'blush',
            'baseColorValue': '#C8102E',
            'adjustedColorValue': CustomPaletteColorModel.adjust(
              _swatch('Red').color,
              saturation: red.saturation,
              lightness: 80,
            ).value,
            'colorLabel': 'Red',
            'finishCode': 'matte',
          },
          {
            'categoryCode': 'lipstick',
            'baseColorValue': '#7A2E4A',
            'adjustedColorValue': '#7A2E4A',
            'colorLabel': 'Berry',
            'finishCode': 'glossy',
          },
        ],
      });
      expect(controller.state.status, CustomPaletteDraftStatus.submitted);
    });

    test('a double tap is one request', () async {
      completeBlush();
      gateway.gate = Completer<void>();
      final first = controller.generate();
      final second = controller.generate();
      expect(controller.state.isSubmitting, isTrue);
      gateway.gate!.complete();
      await Future.wait([first, second]);
      expect(gateway.requests, hasLength(1));
    });

    test('a succeeded request cannot be sent again without an edit', () async {
      completeBlush();
      await controller.generate();
      await controller.generate();
      expect(gateway.requests, hasLength(1));
    });

    test('edits are refused while a request is in flight', () async {
      completeBlush();
      gateway.gate = Completer<void>();
      final pending = controller.generate();
      controller.setLightness(_blush, 80);
      controller.setEnabled(_blush, enabled: false);
      expect(controller.state.selectionFor(_blush).isAdjusted, isFalse);
      expect(controller.state.selectionFor(_blush).enabled, isTrue);
      gateway.gate!.complete();
      await pending;
    });

    test('a retry after failure keeps the same request id', () async {
      completeBlush();
      gateway.error = const CustomPaletteFailure('Nope.', retryable: true);
      await controller.generate();
      expect(controller.state.status, CustomPaletteDraftStatus.failed);
      expect(controller.state.message, 'Nope.');
      expect(controller.state.retryable, isTrue);

      gateway.error = null;
      await controller.generate();
      expect(gateway.requests.map((r) => r.paletteRequestId), [
        'request-1',
        'request-1',
      ]);
      expect(controller.state.status, CustomPaletteDraftStatus.submitted);
      expect(controller.state.message, isNull);
    });

    test('an edit starts a new logical request', () async {
      completeBlush();
      await controller.generate();
      controller.setLightness(_blush, 80);
      expect(controller.state.paletteRequestId, isNull);
      expect(controller.state.status, CustomPaletteDraftStatus.editing);
      await controller.generate();
      expect(gateway.requests.map((r) => r.paletteRequestId), [
        'request-1',
        'request-2',
      ]);
    });

    test('an unexpected error becomes a safe retryable failure', () async {
      completeBlush();
      gateway.error = StateError('secret detail');
      await controller.generate();
      expect(controller.state.status, CustomPaletteDraftStatus.failed);
      expect(controller.state.message, isNot(contains('secret')));
      expect(controller.state.retryable, isTrue);
    });

    test('a result for a replaced draft is dropped', () async {
      completeBlush();
      gateway.gate = Completer<void>();
      final pending = controller.generate();
      controller.prepareFor(analysisId: 'analysis-2', styleCode: 'bridal');
      gateway.gate!.complete();
      await pending;
      expect(controller.state.status, CustomPaletteDraftStatus.editing);
      expect(controller.state.analysisId, 'analysis-2');
    });
  });
}
