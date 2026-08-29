import 'package:facetune/features/analysis/domain/entities/facial_attributes.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_finish.dart';
import 'package:facetune/features/makeup_kit/domain/value_objects/normalized_hex_color.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_category.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_plan_context.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_product_snapshot.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_source_mode.dart';
import 'package:facetune/features/tutorial_v2/data/models/tutorial_v2_step_spec_codec.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_step_spec.dart';

const tutorialV2FaceAttributes = FacialAttributes(
  faceShape: FaceShape.heart,
  skinTone: SkinTone.medium,
  undertone: Undertone.warm,
  eyeShape: EyeShape.almond,
  lipShape: LipShape.full,
  hairColor: HairColor.darkBrown,
  eyeColor: EyeColor.brown,
);

TutorialV2PlanContext tutorialV2Context({
  TutorialV2SourceMode sourceMode = TutorialV2SourceMode.standardRecommendation,
  String styleCode = 'soft_glam',
  String? recommendationId,
  String canonicalImageId = 'generated-1',
  String canonicalStoragePath =
      'user-1/analyses/analysis-1/generated/rec-1/preview_0001.png',
  TutorialV2SourceMode? canonicalSourceMode,
  TutorialV2RecommendationRef? recommendation,
}) => TutorialV2PlanContext(
  sourceMode: sourceMode,
  styleCode: styleCode,
  faceAttributes: tutorialV2FaceAttributes,
  recommendation:
      recommendation ??
      (sourceMode.isMakeupKit
          ? TutorialV2RecommendationRef.kit(recommendationId ?? 'kit-rec-1')
          : TutorialV2RecommendationRef.standard(
              recommendationId ?? 'rec-1',
            )),
  canonicalFinalPreview: TutorialV2CanonicalFinalPreview(
    generatedImageId: canonicalImageId,
    storagePath: canonicalStoragePath,
    sourceMode: canonicalSourceMode ?? sourceMode,
  ),
);

TutorialV2ProductSnapshot tutorialV2Product({
  required TutorialV2Category category,
  String productId = 'product-1',
  String color = '#B86F72',
  MakeupKitFinish finish = MakeupKitFinish.matte,
  String? productName,
  String? colorLabel,
}) => TutorialV2ProductSnapshot(
  productId: productId,
  category: category,
  color: NormalizedHexColor.parse(color),
  finish: finish,
  productName: productName,
  colorLabel: colorLabel,
);

TutorialV2StepDraft tutorialV2Draft(
  TutorialV2Category category, {
  String? title,
  String whatToApply = 'A soft rose blush',
  String whereToApply = 'Upper cheeks',
  String direction = 'Upward toward the temples',
  String technique = 'Soft circular blending',
  String intensity = 'Sheer',
  String faceRationale = 'Heart-shaped faces balance with upper-cheek colour.',
  String targetLookCues = 'Matches the warm flush in the final look.',
  String? amount,
  String? toolSuggestion,
  String? personalizedTip,
  String? avoid,
  TutorialV2ProductSnapshot? productSnapshot,
}) => TutorialV2StepDraft(
  category: category,
  title: title ?? category.label,
  whatToApply: whatToApply,
  whereToApply: whereToApply,
  direction: direction,
  technique: technique,
  intensity: intensity,
  faceRationale: faceRationale,
  targetLookCues: targetLookCues,
  amount: amount,
  toolSuggestion: toolSuggestion,
  personalizedTip: personalizedTip,
  avoid: avoid,
  productSnapshot: productSnapshot,
);

/// Drafts for [categories] plus the mandatory terminal Final Look step.
List<TutorialV2StepDraft> tutorialV2Drafts(
  List<TutorialV2Category> categories,
) => [
  ...categories.map(tutorialV2Draft),
  tutorialV2Draft(TutorialV2Category.finalLook),
];

// ---------------------------------------------------------------------------
// Persistence row fixtures
// ---------------------------------------------------------------------------

const tutorialV2UserId = 'user-1';
const tutorialV2AnalysisId = 'analysis-1';
const tutorialV2SessionId = 'session-1';

/// An `analyses` row carrying the attribute columns the planner reads.
Map<String, Object?> tutorialV2AnalysisRow({
  String faceShape = 'heart',
  String skinTone = 'medium',
  String undertone = 'warm',
  String eyeShape = 'almond',
  String lipShape = 'full',
  String hairColor = 'dark_brown',
  String eyeColor = 'brown',
}) => {
  'id': tutorialV2AnalysisId,
  'face_shape': faceShape,
  'skin_tone': skinTone,
  'undertone': undertone,
  'eye_shape': eyeShape,
  'lip_shape': lipShape,
  'hair_color': hairColor,
  'eye_color': eyeColor,
};

/// A `tutorial_v2_sessions` row.
Map<String, Object?> tutorialV2SessionRow({
  String id = tutorialV2SessionId,
  String userId = tutorialV2UserId,
  String analysisId = tutorialV2AnalysisId,
  TutorialV2SourceMode sourceMode = TutorialV2SourceMode.standardRecommendation,
  String styleCode = 'soft_glam',
  String status = 'plan_ready',
  int totalSteps = 3,
  int planVersion = 2,
  String canonicalImageId = 'generated-1',
  String? canonicalPath,
  String? planError,
}) {
  final isKit = sourceMode.isMakeupKit;
  return {
    'id': id,
    'user_id': userId,
    'analysis_id': analysisId,
    'source_mode': sourceMode.code,
    'recommendation_id': isKit ? null : 'rec-1',
    'kit_recommendation_id': isKit ? 'kit-rec-1' : null,
    'makeup_style': styleCode,
    'canonical_generated_image_id': isKit ? null : canonicalImageId,
    'canonical_kit_generated_image_id': isKit ? canonicalImageId : null,
    'canonical_image_path':
        canonicalPath ??
        '$userId/analyses/$analysisId/generated/rec-1/preview_0001.png',
    'total_steps': totalSteps,
    'plan_version': planVersion,
    'status': status,
    'planner_model': null,
    'planner_prompt_version': null,
    'plan_error': planError,
    'created_at': '2026-08-26T00:00:00Z',
    'updated_at': '2026-08-26T00:00:00Z',
  };
}

/// A `tutorial_v2_steps` row built from an authored draft.
Map<String, Object?> tutorialV2StepRow({
  required int stepIndex,
  required TutorialV2StepDraft draft,
  String? id,
  String userId = tutorialV2UserId,
  String sessionId = tutorialV2SessionId,
  String guidelineStatus = 'pending',
  String resultStatus = 'pending',
  String? guidelinePath,
  String? resultPath,
  String? guidelineError,
  String? resultError,
  int retryCount = 0,
  Object? specOverride,
  String? categoryOverride,
}) => {
  'id': id ?? 'step-$stepIndex',
  'user_id': userId,
  'tutorial_v2_session_id': sessionId,
  'step_index': stepIndex,
  'category': categoryOverride ?? draft.category.code,
  'step_spec_json': specOverride ?? TutorialV2StepSpecCodec.encodeDraft(draft),
  'product_snapshot_json': TutorialV2StepSpecCodec.encodeProduct(
    draft.productSnapshot,
  ),
  'guideline_status': guidelineStatus,
  'result_status': resultStatus,
  'guideline_image_path': guidelinePath,
  'result_image_path': resultPath,
  'guideline_error': guidelineError,
  'result_error': resultError,
  'retry_count': retryCount,
  'model_name': null,
  'prompt_version': null,
  'created_at': '2026-08-26T00:00:00Z',
  'updated_at': '2026-08-26T00:00:00Z',
};

/// Step rows for [categories] plus the terminal Final Look step.
List<Map<String, Object?>> tutorialV2StepRows(
  List<TutorialV2Category> categories, {
  String guidelineStatus = 'pending',
  String resultStatus = 'pending',
}) {
  final drafts = tutorialV2Drafts(categories);
  return [
    for (var index = 0; index < drafts.length; index++)
      tutorialV2StepRow(
        stepIndex: index,
        draft: drafts[index],
        guidelineStatus: guidelineStatus,
        resultStatus: resultStatus,
      ),
  ];
}
