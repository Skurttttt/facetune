import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/custom_palette/data/custom_palette_dtos.dart';
import 'package:facetune/features/custom_palette/domain/entities/custom_palette_look.dart';
import 'package:facetune/features/custom_palette/domain/repositories/custom_palette_gateway.dart';
import 'package:facetune/features/custom_palette/presentation/controllers/custom_palette_draft_controller.dart';
import 'package:facetune/features/custom_palette/presentation/controllers/custom_palette_draft_state.dart';
import 'package:facetune/features/custom_palette/presentation/controllers/custom_palette_look_controller.dart';
import 'package:facetune/features/history/presentation/models/history_feed_item.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/tutorial/data/models/tutorial_dtos.dart';
import 'package:facetune/features/tutorial/domain/entities/canonical_preview_ref.dart';
import 'package:facetune/features/tutorial/domain/entities/look_product_snapshot.dart';
import 'package:facetune/features/tutorial/domain/entities/recommendation_source_mode.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_manifest.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_shade_details.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_step_presentation.dart';
import 'package:facetune/features/tutorial/domain/entities/validated_look_plan.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/analysis_response_fixture.dart';
import '../../helpers/custom_palette_fixture.dart';

const _noDelay = Duration.zero;

CustomPaletteLookController _lookController(
  FakePaletteGateway gateway, {
  int maximumReplays = 3,
}) {
  var issued = 0;
  return CustomPaletteLookController(
    gateway,
    newOperationId: () => 'operation-${++issued}',
    replayDelay: _noDelay,
    maximumReplays: maximumReplays,
  );
}

const _inProgress = CustomPaletteFailure(
  'Still creating.',
  retryable: true,
  code: 'preview_in_progress',
  requestEnded: false,
);
const _connectionLost = CustomPaletteFailure(
  'The connection was interrupted.',
  retryable: true,
  requestEnded: false,
);
const _ended = CustomPaletteFailure(
  'These colors could not be matched.',
  retryable: true,
  code: 'palette_preview_mismatch',
);

TutorialManifest _manifest({
  required RecommendationSourceMode mode,
  required List<TutorialManifestItem> items,
  TutorialManifestStatus status = TutorialManifestStatus.accepted,
}) => TutorialManifest(
  canonicalPreviewId: 'preview-1',
  sourceMode: mode,
  status: status,
  items: items,
  modelId: 'model',
  promptVersion: 'tutorial_manifest_v4_1',
  schemaVersion: 'tutorial_manifest_schema_v1',
  createdAt: DateTime.utc(2026, 11, 2),
);

ValidatedLookPlan _palettePlan() => LookPlanDto.fromRow({
  'id': 'palette-1',
  'analysis_id': 'analysis-1',
  'makeup_style': 'soft_glam',
  'model_name': 'test-model',
  'prompt_version': 'custom_palette_recommendation_v1',
  'created_at': '2026-11-02T00:00:00Z',
  'palette_snapshot_json': [
    paletteRow(),
    paletteRow(
      category: 'lipstick',
      base: '#6A2FB5',
      adjusted: '#6A2FB5',
      label: 'Violet',
      finish: 'glossy',
    ),
  ],
  'recommendation_json': {
    'applications': [applicationRow('blush'), applicationRow('lipstick')],
    'overallIntensity': 'soft',
    'summary': 'A balanced look.',
  },
}, sourceMode: RecommendationSourceMode.customColorPalette);

void main() {
  group('source mode', () {
    test('the third mode has its stable code, in every direction', () {
      expect(
        RecommendationSourceMode.customColorPalette.code,
        'custom_color_palette',
      );
      expect(
        RecommendationSourceMode.fromCode('custom_color_palette'),
        RecommendationSourceMode.customColorPalette,
      );
      for (final mode in RecommendationSourceMode.values) {
        expect(
          RecommendationSourceMode.fromRecommendationMode(
            mode.toRecommendationMode(),
          ),
          mode,
        );
      }
    });

    test('a preview reference never reads as another mode', () {
      const ref = CanonicalPreviewRef.customColorPalette('p');
      expect(ref.isCustomPalette, isTrue);
      expect(ref.isMyMakeupKit, isFalse);
      expect(const CanonicalPreviewRef.standard('p').isCustomPalette, isFalse);
      expect(
        const CanonicalPreviewRef.myMakeupKit('p').isCustomPalette,
        isFalse,
      );
    });
  });

  group('Tutorial', () {
    test('receives the frozen palette as its plan', () {
      final plan = _palettePlan();
      expect(plan.sourceMode, RecommendationSourceMode.customColorPalette);
      final blush = plan.paletteShadesFor(TutorialCategory.blush).single;
      expect(blush.adjustedColor.value, '#D93A52');
      expect(blush.finish.code, 'matte');
      final lips = plan.paletteShadesFor(TutorialCategory.lips).single;
      expect(lips.category, MakeupKitCategory.lipstick);
      expect(lips.adjustedColor.value, '#6A2FB5');
    });

    test('a category outside the palette has nothing to present', () {
      final plan = _palettePlan();
      expect(plan.paletteShadesFor(TutorialCategory.eyeliner), isEmpty);
      expect(plan.paletteShadesFor(TutorialCategory.foundation), isEmpty);
    });

    test('it carries no kit products and no Standard entries', () {
      final plan = _palettePlan();
      expect(plan.productSnapshot, same(LookProductSnapshot.empty));
      expect(plan.standardEntriesFor(TutorialCategory.blush), isEmpty);
    });

    test('colors and finishes presented are exactly the frozen ones', () {
      final presentation = TutorialStepPresentation.fromLookPlan(
        _palettePlan(),
        TutorialCategory.blush,
      );
      expect(
        presentation.sourceMode,
        RecommendationSourceMode.customColorPalette,
      );
      final shade = presentation.product.shades.single;
      expect(shade.color?.value, '#D93A52');
      expect(shade.shadeName, 'Red, adjusted');
      expect((shade.finish! as ControlledFinish).finish.code, 'matte');
    });

    test('a selected category is a step even when judged absent', () {
      final manifest = _manifest(
        mode: RecommendationSourceMode.customColorPalette,
        items: const [
          TutorialManifestItem(
            category: TutorialCategory.blush,
            presence: TutorialCategoryPresence.absent,
            paletteBacked: true,
          ),
          TutorialManifestItem(
            category: TutorialCategory.lips,
            presence: TutorialCategoryPresence.uncertain,
            paletteBacked: true,
          ),
          TutorialManifestItem(
            category: TutorialCategory.foundation,
            presence: TutorialCategoryPresence.present,
          ),
        ],
      );
      expect(manifest.includedCategories, [
        TutorialCategory.blush,
        TutorialCategory.lips,
      ]);
      expect(manifest.isUsable, isTrue);
      expect(manifest.hasKitPreviewMismatch, isFalse);
    });

    test('Standard Tutorial still follows visual presence alone', () {
      final manifest = _manifest(
        mode: RecommendationSourceMode.standard,
        items: const [
          TutorialManifestItem(
            category: TutorialCategory.blush,
            presence: TutorialCategoryPresence.absent,
            paletteBacked: true,
          ),
          TutorialManifestItem(
            category: TutorialCategory.lips,
            presence: TutorialCategoryPresence.present,
          ),
        ],
      );
      expect(manifest.includedCategories, [TutorialCategory.lips]);
    });

    test('My Makeup Kit Tutorial still follows the product snapshot alone', () {
      final manifest = _manifest(
        mode: RecommendationSourceMode.myMakeupKit,
        status: TutorialManifestStatus.kitPreviewMismatch,
        items: const [
          TutorialManifestItem(
            category: TutorialCategory.blush,
            presence: TutorialCategoryPresence.absent,
            productBacked: true,
          ),
          TutorialManifestItem(
            category: TutorialCategory.lips,
            presence: TutorialCategoryPresence.present,
            paletteBacked: true,
          ),
        ],
      );
      expect(manifest.includedCategories, [TutorialCategory.blush]);
      expect(manifest.hasKitPreviewMismatch, isTrue);
      expect(manifest.isUsable, isTrue);
    });

    test('a kit mismatch status is not usable for Custom Color Palette', () {
      final manifest = _manifest(
        mode: RecommendationSourceMode.customColorPalette,
        status: TutorialManifestStatus.kitPreviewMismatch,
        items: const [],
      );
      expect(manifest.isUsable, isFalse);
    });
  });

  group('stored palette', () {
    test('an invalid stored palette is refused rather than shown', () {
      for (final bad in <Object?>[
        null,
        <Object?>[],
        [paletteRow(category: 'foundation')],
        [paletteRow(finish: 'glossy')],
        [paletteRow(adjusted: 'pink')],
      ]) {
        expect(
          () => CustomPaletteDtos.palette(bad),
          throwsA(anyOf(isA<FormatException>(), isA<ArgumentError>())),
          reason: '$bad',
        );
      }
    });
  });

  group('variation', () {
    test('reuses the same frozen palette, as a new request', () async {
      final gateway = FakePaletteGateway();
      final controller = _lookController(gateway);
      addTearDown(controller.dispose);
      final look = paletteRecommendation();

      await controller.start(look);
      final first = controller.state.preview!;
      final palette = controller.state.recommendation!.palette;
      await controller.generateVariation();

      expect(gateway.previewRecommendations, ['palette-1', 'palette-1']);
      expect(gateway.operations, ['operation-1', 'operation-2']);
      expect(controller.state.preview!.id, isNot(first.id));
      expect(controller.state.recommendation!.id, 'palette-1');
      expect(controller.state.recommendation!.palette, same(palette));
    });

    test('a failed variation keeps the look already on screen', () async {
      final gateway = FakePaletteGateway();
      final controller = _lookController(gateway);
      addTearDown(controller.dispose);
      await controller.start(paletteRecommendation());
      final first = controller.state.preview!;

      gateway.previewFailures.add(_ended);
      await controller.generateVariation();

      expect(controller.state.status, CustomPaletteLookStatus.failure);
      expect(controller.state.previousPreview?.id, first.id);
      controller.showPreviousResult();
      expect(controller.state.preview?.id, first.id);
      expect(controller.state.recommendation?.id, 'palette-1');
    });
  });

  group('operation id', () {
    test('an in-progress answer replays the same operation', () async {
      final gateway = FakePaletteGateway()
        ..previewFailures.addAll([_inProgress, _inProgress]);
      final controller = _lookController(gateway);
      addTearDown(controller.dispose);

      await controller.start(paletteRecommendation());

      expect(gateway.operations, ['operation-1', 'operation-1', 'operation-1']);
      expect(controller.state.status, CustomPaletteLookStatus.success);
    });

    test('a lost connection replays the same operation', () async {
      final gateway = FakePaletteGateway()
        ..previewFailures.add(_connectionLost);
      final controller = _lookController(gateway);
      addTearDown(controller.dispose);

      await controller.start(paletteRecommendation());

      expect(gateway.operations, ['operation-1', 'operation-1']);
      expect(controller.state.status, CustomPaletteLookStatus.success);
    });

    test('replays are bounded, and retry keeps the unresolved id', () async {
      final gateway = FakePaletteGateway()
        ..previewFailures.addAll(List.filled(4, _inProgress));
      final controller = _lookController(gateway);
      addTearDown(controller.dispose);

      await controller.start(paletteRecommendation());
      expect(gateway.operations, hasLength(4));
      expect(controller.state.status, CustomPaletteLookStatus.failure);

      await controller.retry();
      expect(gateway.operations.toSet(), {'operation-1'});
      expect(controller.state.status, CustomPaletteLookStatus.success);
    });

    test('a request that definitively ended gets a new id on retry', () async {
      final gateway = FakePaletteGateway()..previewFailures.add(_ended);
      final controller = _lookController(gateway);
      addTearDown(controller.dispose);

      await controller.start(paletteRecommendation());
      expect(controller.state.status, CustomPaletteLookStatus.failure);
      await controller.retry();

      expect(gateway.operations, ['operation-1', 'operation-2']);
    });

    test('returning to a finished look generates nothing', () async {
      final gateway = FakePaletteGateway();
      final controller = _lookController(gateway);
      addTearDown(controller.dispose);
      final look = paletteRecommendation();

      await controller.start(look);
      await controller.start(look);

      expect(gateway.operations, hasLength(1));
    });
  });

  group('restore', () {
    test('a historical look shows its own palette', () {
      final controller = _lookController(FakePaletteGateway());
      addTearDown(controller.dispose);
      controller.restore(
        recommendation: paletteRecommendation(),
        preview: palettePreview(),
      );
      expect(controller.state.status, CustomPaletteLookStatus.success);
      expect(
        controller.state.recommendation!.palette.single.adjustedColor.value,
        '#D93A52',
      );
    });

    test('mismatched lineage is refused', () {
      final controller = _lookController(FakePaletteGateway());
      addTearDown(controller.dispose);
      expect(
        () => controller.restore(
          recommendation: paletteRecommendation(id: 'palette-2'),
          preview: palettePreview(),
        ),
        throwsArgumentError,
      );
    });

    test('a variation of a restored look reuses that look palette', () async {
      final gateway = FakePaletteGateway();
      final controller = _lookController(gateway);
      addTearDown(controller.dispose);
      controller.restore(
        recommendation: paletteRecommendation(id: 'palette-9'),
        preview: palettePreview(recommendationId: 'palette-9'),
      );
      await controller.generateVariation();
      expect(gateway.previewRecommendations, ['palette-9']);
    });

    test('the editor draft cannot change what a look shows', () {
      final gateway = FakePaletteGateway();
      final look = _lookController(gateway);
      final draft = CustomPaletteDraftController(gateway);
      addTearDown(look.dispose);
      addTearDown(draft.dispose);
      look.restore(
        recommendation: paletteRecommendation(),
        preview: palettePreview(),
      );
      draft.startFromLook(look.state.recommendation!);
      draft.setLightness(MakeupKitCategory.blush, 90);

      expect(
        look.state.recommendation!.palette.single.adjustedColor.value,
        '#D93A52',
      );
    });
  });

  group('editing', () {
    test('a draft from a look starts from its exact frozen values', () {
      final draft = CustomPaletteDraftController(FakePaletteGateway());
      addTearDown(draft.dispose);
      draft.startFromLook(paletteRecommendation());

      final selection = draft.state.selectionFor(MakeupKitCategory.blush);
      expect(selection.enabled, isTrue);
      expect(selection.base?.hex, '#C8102E');
      expect(selection.adjustedColor?.value, '#D93A52');
      expect(selection.finish?.code, 'matte');
      expect(draft.state.derivedFromPaletteId, 'palette-1');
      expect(draft.state.paletteRequestId, isNull);
      expect(draft.state.isValid, isTrue);
    });

    test('an edit creates a new logical palette, linked to the old', () async {
      final gateway = FakePaletteGateway();
      var issued = 0;
      final draft = CustomPaletteDraftController(
        gateway,
        newId: () => 'request-${++issued}',
      );
      addTearDown(draft.dispose);
      final original = paletteRecommendation();

      draft.startFromLook(original);
      draft.setLightness(MakeupKitCategory.blush, 80);
      await draft.generate();

      final request = gateway.requests.single;
      expect(request.paletteRequestId, 'request-1');
      expect(request.derivedFromPaletteId, 'palette-1');
      expect(request.analysisId, original.analysisId);
      expect(request.selections.single.adjustedColorValue, isNot('#D93A52'));
      expect(draft.state.status, CustomPaletteDraftStatus.submitted);
      expect(draft.state.recommendation?.derivedFromPaletteId, 'palette-1');
      // The original look's record is untouched.
      expect(original.palette.single.adjustedColor.value, '#D93A52');
    });

    test('an unedited restart sends the exact stored color', () async {
      final gateway = FakePaletteGateway();
      final draft = CustomPaletteDraftController(gateway);
      addTearDown(draft.dispose);

      draft.startFromLook(paletteRecommendation());
      await draft.generate();

      final selection = gateway.requests.single.selections.single;
      expect(selection.adjustedColorValue, '#D93A52');
      expect(selection.baseColorValue, '#C8102E');
      expect(selection.colorLabel, 'Red');
      expect(selection.finishCode, 'matte');
    });
  });

  group('History feed', () {
    final analysis = FaceAnalysisDto.fromResponse(
      validAnalysisResponse,
    ).analysis;
    final style = MakeupStyleCatalog.styles.first;

    CustomPaletteHistoryEntry entry({bool saved = false}) {
      final result = CustomPaletteLookResult(
        analysis: analysis,
        style: style,
        recommendation: paletteRecommendation(),
        preview: palettePreview(),
      );
      return CustomPaletteHistoryEntry(
        result: result,
        savedLook: saved
            ? CustomPaletteSavedLook(
                id: 'saved-1',
                result: result,
                isFavorite: true,
                createdAt: DateTime.utc(2026, 11, 2),
              )
            : null,
      );
    }

    test('a look appears as its own mode, from its frozen palette', () {
      final feed = buildHistoryFeed(
        recommendations: const [],
        myMakeupKit: const [],
        customPalette: [entry()],
      );
      final item = feed.single;
      expect(item, isA<CustomPaletteHistoryFeedItem>());
      expect(item.modeLabel, 'Custom Color Palette');
      expect(item.metadataLabel, '1 color');
      expect(item.isComplete, isTrue);
      expect(item.presentationKey, 'customColorPalette:preview-1');
    });

    test('the type filter separates the three modes', () {
      List<HistoryFeedItem> filtered(HistoryFeedTypeFilter filter) =>
          buildHistoryFeed(
            recommendations: const [],
            myMakeupKit: const [],
            customPalette: [entry()],
            typeFilter: filter,
          );
      expect(filtered(HistoryFeedTypeFilter.all), hasLength(1));
      expect(filtered(HistoryFeedTypeFilter.customPalette), hasLength(1));
      expect(filtered(HistoryFeedTypeFilter.myMakeupKit), isEmpty);
      expect(filtered(HistoryFeedTypeFilter.recommendations), isEmpty);
    });

    test('search reads the frozen palette', () {
      List<HistoryFeedItem> search(String query) => buildHistoryFeed(
        recommendations: const [],
        myMakeupKit: const [],
        customPalette: [entry()],
        query: query,
      );
      expect(search('#d93a52'), hasLength(1));
      expect(search('matte'), hasLength(1));
      expect(search('violet'), isEmpty);
    });

    test('favorite state comes from the saved look', () {
      final item = buildHistoryFeed(
        recommendations: const [],
        myMakeupKit: const [],
        customPalette: [entry(saved: true)],
      ).single;
      expect(item.isFavorite, isTrue);
    });
  });
}
