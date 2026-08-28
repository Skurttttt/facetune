import 'package:facetune/features/analysis/domain/entities/facial_attributes.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_finish.dart';
import 'package:facetune/features/makeup_kit/domain/value_objects/normalized_hex_color.dart';
import 'package:facetune/features/tutorial_v3/data/models/tutorial_v3_geometry_codec.dart';
import 'package:facetune/features/tutorial_v3/domain/catalog/tutorial_v3_geometry_catalog.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_category.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_geometry.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_guideline_graphic.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_guideline_visual_intent.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_plan.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_product_snapshot.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_scoped_face_attributes.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_source_mode.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_step_spec.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_target_reference_mode.dart';
import 'package:facetune/features/tutorial_v3/domain/value_objects/tutorial_v3_plan_version.dart';

/// A complete analysis result the scoping helper narrows per category.
const testFacialAttributes = FacialAttributes(
  faceShape: FaceShape.round,
  skinTone: SkinTone.medium,
  undertone: Undertone.warm,
  eyeShape: EyeShape.almond,
  lipShape: LipShape.full,
  hairColor: HairColor.black,
  eyeColor: EyeColor.brown,
);

const testStyleCode = 'soft_glam';

const testOwnedProductId = 'e2c0d1b6-0000-4000-8000-000000000001';

/// Builds a valid guideline step, with defaults that stay valid for whatever
/// [category] and [sourceMode] are passed.
TutorialV3GuidelineStepSpec guidelineStep({
  int stepIndex = 1,
  TutorialV3Category category = TutorialV3Category.blush,
  TutorialV3SourceMode sourceMode = TutorialV3SourceMode.standard,
  String selectedStyleCode = testStyleCode,
  TutorialV3PlanVersion? planVersion,
  TutorialV3TargetReferenceMode targetReferenceMode =
      TutorialV3TargetReferenceMode.fullCanonicalPreview,
  TutorialV3ProductSnapshot? productSnapshot,
  bool omitProductSnapshot = false,
  TutorialV3ScopedFaceAttributes? relevantFaceAttributes,
  String whereToApply = 'Upper outer cheeks',
  String direction = 'Upward toward the temples',
  String technique = 'Soft circular blending',
  String faceRationale = 'Lifted placement adds length to a round face.',
  String targetRationale = 'Matches the soft flush in the target look.',
  List<String>? targetLookCues,
  String? coverage,
  String? intensity,
  String? amount,
  String? toolSuggestion,
  String? personalizedTip,
  String? avoid,
  TutorialV3GuidelineVisualIntent? guidelineVisualIntent,
}) {
  final snapshot = omitProductSnapshot
      ? null
      : productSnapshot ??
            (sourceMode.isKit
                ? kitProductSnapshot(category: category)
                : standardProductSnapshot(category: category));

  return TutorialV3GuidelineStepSpec(
    stepIndex: stepIndex,
    category: category,
    sourceMode: sourceMode,
    selectedStyleCode: selectedStyleCode,
    planVersion: planVersion ?? TutorialV3PlanVersion.current,
    targetReferenceMode: targetReferenceMode,
    productSnapshot: snapshot,
    coverage: coverage,
    intensity: intensity,
    whereToApply: whereToApply,
    direction: direction,
    technique: technique,
    amount: amount,
    toolSuggestion: toolSuggestion,
    personalizedTip: personalizedTip,
    avoid: avoid,
    relevantFaceAttributes:
        relevantFaceAttributes ??
        TutorialV3ScopedFaceAttributes.scope(testFacialAttributes, category),
    faceRationale: faceRationale,
    targetRationale: targetRationale,
    targetLookCues: targetLookCues ?? const ['Soft diffused flush'],
    guidelineVisualIntent:
        guidelineVisualIntent ??
        const TutorialV3GuidelineVisualIntent(
          description: 'Translucent band across the upper outer cheek.',
          graphics: {
            TutorialV3GuidelineGraphic.translucentZone,
            TutorialV3GuidelineGraphic.arrow,
          },
        ),
  );
}

TutorialV3FinalLookStepSpec finalLookStep({
  int stepIndex = 2,
  TutorialV3SourceMode sourceMode = TutorialV3SourceMode.standard,
  String selectedStyleCode = testStyleCode,
  TutorialV3PlanVersion? planVersion,
  TutorialV3TargetReferenceMode targetReferenceMode =
      TutorialV3TargetReferenceMode.fullCanonicalPreview,
  String targetRationale = 'The completed soft glam look.',
}) => TutorialV3FinalLookStepSpec(
  stepIndex: stepIndex,
  sourceMode: sourceMode,
  selectedStyleCode: selectedStyleCode,
  planVersion: planVersion ?? TutorialV3PlanVersion.current,
  targetReferenceMode: targetReferenceMode,
  targetRationale: targetRationale,
);

TutorialV3ProductSnapshot standardProductSnapshot({
  TutorialV3Category category = TutorialV3Category.blush,
}) => TutorialV3ProductSnapshot(
  category: category.kitCategory!,
  productName: 'Recommended shade',
  shadeName: 'Soft Rose',
  color: NormalizedHexColor.parse('#B86F72'),
  finish: MakeupKitFinish.satin,
);

TutorialV3ProductSnapshot kitProductSnapshot({
  TutorialV3Category category = TutorialV3Category.blush,
  String productId = testOwnedProductId,
}) => TutorialV3ProductSnapshot(
  category: category.kitCategory!,
  productId: productId,
  productName: 'My blush',
  shadeName: 'Soft Rose',
  color: NormalizedHexColor.parse('#B86F72'),
  finish: MakeupKitFinish.satin,
);

/// Builds a plan from [steps], defaulting to a minimal valid two-step plan.
TutorialV3Plan planOf({
  List<TutorialV3StepSpec>? steps,
  TutorialV3SourceMode sourceMode = TutorialV3SourceMode.standard,
  String selectedStyleCode = testStyleCode,
  TutorialV3PlanVersion? planVersion,
}) => TutorialV3Plan(
  planVersion: planVersion ?? TutorialV3PlanVersion.current,
  sourceMode: sourceMode,
  selectedStyleCode: selectedStyleCode,
  steps:
      steps ??
      [
        guidelineStep(stepIndex: 1, sourceMode: sourceMode),
        finalLookStep(stepIndex: 2, sourceMode: sourceMode),
      ],
);

/// Builds a plan that teaches [categories] in order and ends with the final
/// look, renumbering the steps automatically.
TutorialV3Plan planTeaching(
  List<TutorialV3Category> categories, {
  TutorialV3SourceMode sourceMode = TutorialV3SourceMode.standard,
}) {
  final steps = <TutorialV3StepSpec>[
    for (var index = 0; index < categories.length; index++)
      guidelineStep(
        stepIndex: index + 1,
        category: categories[index],
        sourceMode: sourceMode,
      ),
    finalLookStep(stepIndex: categories.length + 1, sourceMode: sourceMode),
  ];
  return planOf(steps: steps, sourceMode: sourceMode);
}

/// A minimal valid geometry document for [category].
///
/// The primitive is chosen from the catalog rather than hard-coded, so the
/// fixture is legal for every category — a `placement_zone` would be rejected
/// on foundation, and an `application_path` on blush.
TutorialV3Geometry testGeometry({
  TutorialV3Category category = TutorialV3Category.blush,
  int schemaVersion = tutorialV3GeometrySchemaVersion,
  List<TutorialV3Primitive>? primitives,
}) => TutorialV3Geometry(
  schemaVersion: schemaVersion,
  category: category,
  coordinateSpace: tutorialV3CoordinateSpace,
  primitives: primitives ?? [_primitiveFor(category)],
);

TutorialV3Primitive _primitiveFor(TutorialV3Category category) {
  final roles = TutorialV3GeometryCatalog.rolesFor(category);
  for (final role in TutorialV3GeometryRole.values) {
    if (!roles.contains(role)) continue;
    final kinds = TutorialV3GeometryCatalog.kindsFor(role);
    if (kinds.contains(TutorialV3PrimitiveKind.ellipse)) {
      return TutorialV3Ellipse(
        role: role,
        center: const NormalizedPoint(0.3, 0.45),
        radiusX: 0.09,
        radiusY: 0.06,
      );
    }
    if (kinds.contains(TutorialV3PrimitiveKind.polyline)) {
      return TutorialV3Polyline(
        role: role,
        vertices: const [NormalizedPoint(0.3, 0.45), NormalizedPoint(0.4, 0.43)],
      );
    }
    if (kinds.contains(TutorialV3PrimitiveKind.arrow)) {
      return TutorialV3Arrow(
        role: role,
        start: const NormalizedPoint(0.3, 0.45),
        end: const NormalizedPoint(0.4, 0.38),
      );
    }
    if (kinds.contains(TutorialV3PrimitiveKind.marker)) {
      return TutorialV3Marker(
        role: role,
        position: const NormalizedPoint(0.3, 0.45),
      );
    }
  }
  throw ArgumentError.value(
    category,
    'category',
    'teaches no geometry, so it has no valid fixture',
  );
}

/// The wire form of [testGeometry], as the database stores it.
Map<String, dynamic> testGeometryJson({
  TutorialV3Category category = TutorialV3Category.blush,
}) => TutorialV3GeometryCodec.encode(testGeometry(category: category));
