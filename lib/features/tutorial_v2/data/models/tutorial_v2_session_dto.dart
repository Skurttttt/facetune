import '../../../analysis/domain/entities/facial_attributes.dart';
import '../../domain/entities/tutorial_v2_category.dart';
import '../../domain/entities/tutorial_v2_generation_status.dart';
import '../../domain/entities/tutorial_v2_plan.dart';
import '../../domain/entities/tutorial_v2_plan_context.dart';
import '../../domain/entities/tutorial_v2_plan_version.dart';
import '../../domain/entities/tutorial_v2_session.dart';
import '../../domain/entities/tutorial_v2_session_snapshot.dart';
import '../../domain/entities/tutorial_v2_source_mode.dart';
import '../../domain/entities/tutorial_v2_step_spec.dart';
import 'tutorial_v2_step_spec_codec.dart';

/// Reads the face attributes the planner needs off a raw `analyses` row.
///
/// The values are the same snake_case codes `FaceAnalysisDto` already
/// accepts; this reads them from the database column names rather than from
/// an Edge Function response envelope.
abstract final class TutorialV2FacialAttributesCodec {
  static FacialAttributes fromAnalysisRow(Map<String, Object?> row) =>
      FacialAttributes(
        faceShape: _value(row, 'face_shape', _faceShapes),
        skinTone: _value(row, 'skin_tone', _skinTones),
        undertone: _value(row, 'undertone', _undertones),
        eyeShape: _value(row, 'eye_shape', _eyeShapes),
        lipShape: _value(row, 'lip_shape', _lipShapes),
        hairColor: _value(row, 'hair_color', _hairColors),
        eyeColor: _value(row, 'eye_color', _eyeColors),
      );

  static T _value<T>(
    Map<String, Object?> row,
    String column,
    Map<String, T> values,
  ) {
    final value = row[column];
    if (value is! String || !values.containsKey(value)) {
      throw FormatException('analyses.$column has an unsupported value.');
    }
    return values[value] as T;
  }

  static const _faceShapes = {
    'oval': FaceShape.oval,
    'round': FaceShape.round,
    'square': FaceShape.square,
    'heart': FaceShape.heart,
    'oblong': FaceShape.oblong,
    'diamond': FaceShape.diamond,
    'triangle': FaceShape.triangle,
  };
  static const _skinTones = {
    'very_light': SkinTone.veryLight,
    'light': SkinTone.light,
    'medium': SkinTone.medium,
    'tan': SkinTone.tan,
    'deep': SkinTone.deep,
    'very_deep': SkinTone.veryDeep,
  };
  static const _undertones = {
    'warm': Undertone.warm,
    'cool': Undertone.cool,
    'neutral': Undertone.neutral,
    'olive': Undertone.olive,
  };
  static const _eyeShapes = {
    'almond': EyeShape.almond,
    'round': EyeShape.round,
    'hooded': EyeShape.hooded,
    'monolid': EyeShape.monolid,
    'upturned': EyeShape.upturned,
    'downturned': EyeShape.downturned,
    'deep_set': EyeShape.deepSet,
    'protruding': EyeShape.protruding,
  };
  static const _lipShapes = {
    'thin': LipShape.thin,
    'medium': LipShape.medium,
    'full': LipShape.full,
    'heart_shaped': LipShape.heartShaped,
    'wide': LipShape.wide,
    'round': LipShape.round,
  };
  static const _hairColors = {
    'black': HairColor.black,
    'dark_brown': HairColor.darkBrown,
    'brown': HairColor.brown,
    'light_brown': HairColor.lightBrown,
    'blonde': HairColor.blonde,
    'red': HairColor.red,
    'gray': HairColor.gray,
    'white': HairColor.white,
    'other': HairColor.other,
  };
  static const _eyeColors = {
    'dark_brown': EyeColor.darkBrown,
    'brown': EyeColor.brown,
    'hazel': EyeColor.hazel,
    'amber': EyeColor.amber,
    'green': EyeColor.green,
    'blue': EyeColor.blue,
    'gray': EyeColor.gray,
    'other': EyeColor.other,
  };
}

/// Converts between `tutorial_v2_sessions` / `tutorial_v2_steps` rows and the
/// V2 domain.
abstract final class TutorialV2SessionDto {
  static const sessionColumns =
      'id,user_id,analysis_id,source_mode,recommendation_id,'
      'kit_recommendation_id,makeup_style,canonical_generated_image_id,'
      'canonical_kit_generated_image_id,canonical_image_path,total_steps,'
      'plan_version,status,planner_model,planner_prompt_version,plan_error,'
      'created_at,updated_at';

  static const stepColumns =
      'id,user_id,tutorial_v2_session_id,step_index,category,step_spec_json,'
      'product_snapshot_json,guideline_status,result_status,'
      'guideline_image_path,result_image_path,guideline_error,result_error,'
      'retry_count,model_name,prompt_version,created_at,updated_at';

  static const analysisColumns =
      'id,face_shape,skin_tone,undertone,eye_shape,lip_shape,hair_color,'
      'eye_color';

  /// Values for a new session row, before any plan exists.
  static Map<String, Object?> insertValues({
    required String userId,
    required String analysisId,
    required TutorialV2PlanContext context,
  }) {
    final isKit = context.sourceMode.isMakeupKit;
    return {
      'user_id': userId,
      'analysis_id': analysisId,
      'source_mode': context.sourceMode.code,
      'recommendation_id': context.recommendation.recommendationId,
      'kit_recommendation_id': context.recommendation.kitRecommendationId,
      'makeup_style': context.styleCode,
      'canonical_generated_image_id': isKit
          ? null
          : context.canonicalFinalPreview.generatedImageId,
      'canonical_kit_generated_image_id': isKit
          ? context.canonicalFinalPreview.generatedImageId
          : null,
      'canonical_image_path': context.canonicalFinalPreview.storagePath,
      'total_steps': 0,
      'plan_version': context.planVersion.value,
      'status': TutorialV2SessionStatus.pending.code,
    };
  }

  /// Values for one persisted step of a validated plan.
  static Map<String, Object?> stepInsertValues({
    required String userId,
    required String sessionId,
    required TutorialV2StepSpec step,
  }) => {
    'user_id': userId,
    'tutorial_v2_session_id': sessionId,
    'step_index': step.stepIndex,
    'category': step.category.code,
    'step_spec_json': TutorialV2StepSpecCodec.encode(step),
    'product_snapshot_json': TutorialV2StepSpecCodec.encodeProduct(
      step.productSnapshot,
    ),
    'guideline_status': step.requiresGuidelineAsset
        ? TutorialV2GenerationStatus.pending.code
        : TutorialV2GenerationStatus.ready.code,
    'result_status': TutorialV2GenerationStatus.pending.code,
  };

  /// Rebuilds a snapshot from persisted rows.
  ///
  /// Never throws for bad data: a row set that cannot be read is reported
  /// through [TutorialV2SessionSnapshot.integrity] so the caller can replan
  /// instead of crashing on someone else's half-written session.
  static TutorialV2SessionSnapshot fromRows({
    required Map<String, Object?> sessionRow,
    required List<Map<String, Object?>> stepRows,
    required FacialAttributes attributes,
  }) {
    final planVersionValue = _int(sessionRow, 'plan_version');
    final planVersion = TutorialV2PlanVersion.tryParse(planVersionValue);

    final sourceMode = TutorialV2SourceMode.fromCode(
      _string(sessionRow, 'source_mode'),
    );
    if (sourceMode == null) {
      throw FormatException(
        'Unknown source mode "${sessionRow['source_mode']}".',
      );
    }

    final isKit = sourceMode.isMakeupKit;
    final canonicalId = isKit
        ? _string(sessionRow, 'canonical_kit_generated_image_id')
        : _string(sessionRow, 'canonical_generated_image_id');

    final context = TutorialV2PlanContext(
      sourceMode: sourceMode,
      styleCode: _string(sessionRow, 'makeup_style'),
      faceAttributes: attributes,
      recommendation: isKit
          ? TutorialV2RecommendationRef.kit(
              _string(sessionRow, 'kit_recommendation_id'),
            )
          : TutorialV2RecommendationRef.standard(
              _string(sessionRow, 'recommendation_id'),
            ),
      canonicalFinalPreview: TutorialV2CanonicalFinalPreview(
        generatedImageId: canonicalId,
        storagePath: _string(sessionRow, 'canonical_image_path'),
        sourceMode: sourceMode,
      ),
      // Falls back to the current version only when the row is unreadable;
      // in that case the snapshot is reported incompatible and the context
      // is never used to plan anything.
      planVersion: planVersion ?? TutorialV2PlanVersion.current,
    );

    final id = _string(sessionRow, 'id');
    final userId = _string(sessionRow, 'user_id');
    final analysisId = _string(sessionRow, 'analysis_id');
    final totalSteps = _int(sessionRow, 'total_steps');
    final createdAt = _date(sessionRow, 'created_at');
    final updatedAt = _date(sessionRow, 'updated_at');
    final planError = sessionRow['plan_error'] as String?;

    TutorialV2SessionSnapshot build({
      required TutorialV2SessionStatus status,
      required TutorialV2SessionIntegrity integrity,
      TutorialV2Plan? plan,
      List<TutorialV2StepRecord> steps = const [],
    }) => TutorialV2SessionSnapshot(
      id: id,
      userId: userId,
      analysisId: analysisId,
      context: context,
      status: status,
      totalSteps: totalSteps,
      plan: plan,
      steps: steps,
      integrity: integrity,
      planError: planError,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    // A row this build cannot read is routed away from, never reinterpreted
    // and never rewritten.
    if (planVersion == null) {
      return build(
        status: TutorialV2SessionStatus.incompatible,
        integrity: TutorialV2SessionIntegrity.intact,
      );
    }

    final status =
        TutorialV2SessionStatus.fromCode(_string(sessionRow, 'status')) ??
        TutorialV2SessionStatus.pending;

    if (!status.hasPlan) {
      return build(
        status: status,
        integrity: TutorialV2SessionIntegrity.intact,
      );
    }

    if (stepRows.isEmpty) {
      return build(
        status: status,
        integrity: TutorialV2SessionIntegrity.missingSteps,
      );
    }

    final ordered = [...stepRows]
      ..sort(
        (a, b) => _int(a, 'step_index').compareTo(_int(b, 'step_index')),
      );

    final indexes = ordered.map((row) => _int(row, 'step_index')).toList();
    if (indexes.toSet().length != indexes.length) {
      return build(
        status: status,
        integrity: TutorialV2SessionIntegrity.duplicateStepIndex,
      );
    }
    if (ordered.length != totalSteps) {
      return build(
        status: status,
        integrity: TutorialV2SessionIntegrity.stepCountMismatch,
      );
    }

    final drafts = <TutorialV2StepDraft>[];
    final ownedProductIds = <String>{};
    try {
      for (final row in ordered) {
        final snapshot = TutorialV2StepSpecCodec.decodeProduct(
          row['product_snapshot_json'],
        );
        if (snapshot != null) ownedProductIds.add(snapshot.productId);
        final draft = TutorialV2StepSpecCodec.decodeDraft(
          row['step_spec_json'],
          productSnapshot: snapshot,
        );
        // The row's own category column must agree with the spec it holds.
        final rowCategory = TutorialV2Category.fromCode(
          _string(row, 'category'),
        );
        if (rowCategory != draft.category) {
          throw const FormatException('Step category disagrees with its spec.');
        }
        drafts.add(draft);
      }
    } catch (_) {
      return build(
        status: status,
        integrity: TutorialV2SessionIntegrity.unreadableSpec,
      );
    }

    final TutorialV2Plan plan;
    try {
      // `ownedProductIds` comes from the persisted snapshots themselves, not
      // from live inventory. The snapshot IS the historical record of what
      // the user owned when the tutorial was planned, so re-checking against
      // the current Kit would invalidate a saved tutorial the moment the user
      // edits or deletes a product — exactly what snapshots exist to prevent.
      plan = TutorialV2Plan.fromDrafts(
        context: context,
        drafts: drafts,
        ownedProductIds: ownedProductIds,
      );
    } catch (_) {
      return build(
        status: status,
        integrity: TutorialV2SessionIntegrity.unreadableSpec,
      );
    }

    final records = <TutorialV2StepRecord>[];
    for (var index = 0; index < ordered.length; index++) {
      records.add(
        TutorialV2StepRecord(
          id: _string(ordered[index], 'id'),
          spec: plan.stepAt(index),
          assets: _assets(ordered[index]),
        ),
      );
    }

    return build(
      status: status,
      integrity: TutorialV2SessionIntegrity.intact,
      plan: plan,
      steps: records,
    );
  }

  static TutorialV2StepAssets _assets(Map<String, Object?> row) =>
      TutorialV2StepAssets(
        guidelineStatus:
            TutorialV2GenerationStatus.fromCode(
              _string(row, 'guideline_status'),
            ) ??
            TutorialV2GenerationStatus.pending,
        resultStatus:
            TutorialV2GenerationStatus.fromCode(
              _string(row, 'result_status'),
            ) ??
            TutorialV2GenerationStatus.pending,
        guidelinePath: row['guideline_image_path'] as String?,
        resultPath: row['result_image_path'] as String?,
        guidelineError: row['guideline_error'] as String?,
        resultError: row['result_error'] as String?,
        retryCount: row['retry_count'] is int ? row['retry_count'] as int : 0,
      );

  static String _string(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is String && value.trim().isNotEmpty) return value;
    throw FormatException('$key must be a non-empty string.');
  }

  static int _int(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw FormatException('$key must be an integer.');
  }

  static DateTime _date(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw FormatException('$key must be a timestamp.');
  }
}
