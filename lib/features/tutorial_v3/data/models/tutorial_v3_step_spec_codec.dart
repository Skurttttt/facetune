import '../../../analysis/domain/entities/facial_attributes.dart';
import '../../../makeup_kit/domain/entities/makeup_kit_category.dart';
import '../../../makeup_kit/domain/entities/makeup_kit_finish.dart';
import '../../../makeup_kit/domain/value_objects/normalized_hex_color.dart';
import '../../domain/entities/tutorial_v3_category.dart';
import '../../domain/entities/tutorial_v3_guideline_graphic.dart';
import '../../domain/entities/tutorial_v3_guideline_visual_intent.dart';
import '../../domain/entities/tutorial_v3_product_snapshot.dart';
import '../../domain/entities/tutorial_v3_scoped_face_attributes.dart';
import '../../domain/entities/tutorial_v3_source_mode.dart';
import '../../domain/entities/tutorial_v3_step_spec.dart';
import '../../domain/entities/tutorial_v3_target_reference_mode.dart';
import '../../domain/value_objects/tutorial_v3_plan_version.dart';

/// Converts a validated Step Spec to and from the `jsonb` shape persisted in
/// `tutorial_v3_steps`.
///
/// The product snapshot is encoded separately rather than nested inside the
/// spec, because the table stores it in its own `product_snapshot_json`
/// column. Keeping one copy means the column and the spec can never disagree,
/// and the `final_look_has_no_product` check constraint stays meaningful.
///
/// Decoding is strict on purpose. Every enum is looked up by its stable code
/// and an unknown value throws rather than falling back to a default, so a V1
/// or V2 row — or a row written by a newer build — can never be silently
/// reinterpreted as a valid V3 spec.
abstract final class TutorialV3StepSpecCodec {
  /// Encodes [spec] for `step_spec_json`, excluding the product snapshot.
  static Map<String, Object?> encodeSpec(TutorialV3StepSpec spec) {
    final base = <String, Object?>{
      'step_index': spec.stepIndex,
      'category': spec.category.code,
      'source_mode': spec.sourceMode.code,
      'selected_style_code': spec.selectedStyleCode,
      'plan_version': spec.planVersion.value,
      'target_reference_mode': spec.targetReferenceMode.code,
    };

    switch (spec) {
      case TutorialV3FinalLookStepSpec():
        return {...base, 'target_rationale': spec.targetRationale};
      case TutorialV3GuidelineStepSpec():
        return {
          ...base,
          'where_to_apply': spec.whereToApply,
          'direction': spec.direction,
          'technique': spec.technique,
          if (spec.coverage != null) 'coverage': spec.coverage,
          if (spec.intensity != null) 'intensity': spec.intensity,
          if (spec.amount != null) 'amount': spec.amount,
          if (spec.toolSuggestion != null)
            'tool_suggestion': spec.toolSuggestion,
          if (spec.personalizedTip != null)
            'personalized_tip': spec.personalizedTip,
          if (spec.avoid != null) 'avoid': spec.avoid,
          'face_attributes': _encodeAttributes(spec.relevantFaceAttributes),
          'face_rationale': spec.faceRationale,
          'target_rationale': spec.targetRationale,
          'target_look_cues': spec.targetLookCues,
          'guideline_visual_intent': {
            'description': spec.guidelineVisualIntent.description,
            'graphics': spec.guidelineVisualIntent.graphics
                .map((graphic) => graphic.code)
                .toList(growable: false),
          },
        };
    }
  }

  /// Encodes the product snapshot for `product_snapshot_json`, or `null` when
  /// the step teaches no product.
  static Map<String, Object?>? encodeProductSnapshot(TutorialV3StepSpec spec) {
    if (spec is! TutorialV3GuidelineStepSpec) return null;
    final snapshot = spec.productSnapshot;
    if (snapshot == null) return null;
    return <String, Object?>{
      'category': snapshot.category.code,
      if (snapshot.productId != null) 'product_id': snapshot.productId,
      if (snapshot.productName != null) 'product_name': snapshot.productName,
      if (snapshot.shadeName != null) 'shade_name': snapshot.shadeName,
      if (snapshot.color != null) 'color_hex': snapshot.color!.value,
      if (snapshot.finish != null) 'finish': snapshot.finish!.code,
    };
  }

  /// Rebuilds a Step Spec from its persisted parts.
  static TutorialV3StepSpec decode({
    required Map<String, Object?> spec,
    Map<String, Object?>? productSnapshot,
  }) {
    final category = _lookup(
      TutorialV3Category.fromCode(_string(spec, 'category')),
      'category',
      spec['category'],
    );
    final stepIndex = _int(spec, 'step_index');
    final sourceMode = _lookup(
      TutorialV3SourceMode.fromCode(_string(spec, 'source_mode')),
      'source_mode',
      spec['source_mode'],
    );
    final selectedStyleCode = _string(spec, 'selected_style_code');
    final planVersion = TutorialV3PlanVersion.parse(_int(spec, 'plan_version'));
    final targetReferenceMode = _lookup(
      TutorialV3TargetReferenceMode.fromCode(
        _string(spec, 'target_reference_mode'),
      ),
      'target_reference_mode',
      spec['target_reference_mode'],
    );

    if (category.isFinalLook) {
      if (productSnapshot != null) {
        throw const FormatException(
          'The final look step must not carry a product snapshot.',
        );
      }
      return TutorialV3FinalLookStepSpec(
        stepIndex: stepIndex,
        sourceMode: sourceMode,
        selectedStyleCode: selectedStyleCode,
        planVersion: planVersion,
        targetReferenceMode: targetReferenceMode,
        targetRationale: _string(spec, 'target_rationale'),
      );
    }

    final intent = _map(spec, 'guideline_visual_intent');
    return TutorialV3GuidelineStepSpec(
      stepIndex: stepIndex,
      category: category,
      sourceMode: sourceMode,
      selectedStyleCode: selectedStyleCode,
      planVersion: planVersion,
      targetReferenceMode: targetReferenceMode,
      productSnapshot: productSnapshot == null
          ? null
          : _decodeProductSnapshot(productSnapshot),
      coverage: _optionalString(spec, 'coverage'),
      intensity: _optionalString(spec, 'intensity'),
      whereToApply: _string(spec, 'where_to_apply'),
      direction: _string(spec, 'direction'),
      technique: _string(spec, 'technique'),
      amount: _optionalString(spec, 'amount'),
      toolSuggestion: _optionalString(spec, 'tool_suggestion'),
      personalizedTip: _optionalString(spec, 'personalized_tip'),
      avoid: _optionalString(spec, 'avoid'),
      relevantFaceAttributes: _decodeAttributes(_map(spec, 'face_attributes')),
      faceRationale: _string(spec, 'face_rationale'),
      targetRationale: _string(spec, 'target_rationale'),
      targetLookCues: _stringList(spec, 'target_look_cues'),
      guidelineVisualIntent: TutorialV3GuidelineVisualIntent(
        description: _string(intent, 'description'),
        graphics: _stringList(intent, 'graphics')
            .map(
              (code) => _lookup(
                TutorialV3GuidelineGraphic.fromCode(code),
                'graphics',
                code,
              ),
            )
            .toSet(),
      ),
    );
  }

  static TutorialV3ProductSnapshot _decodeProductSnapshot(
    Map<String, Object?> data,
  ) {
    final colorHex = _optionalString(data, 'color_hex');
    final finish = _optionalString(data, 'finish');
    return TutorialV3ProductSnapshot(
      category: _lookup(
        MakeupKitCategory.fromCode(_string(data, 'category')),
        'category',
        data['category'],
      ),
      productId: _optionalString(data, 'product_id'),
      productName: _optionalString(data, 'product_name'),
      shadeName: _optionalString(data, 'shade_name'),
      color: colorHex == null ? null : NormalizedHexColor.parse(colorHex),
      finish: finish == null
          ? null
          : _lookup(MakeupKitFinish.fromCode(finish), 'finish', finish),
    );
  }

  static Map<String, Object?> _encodeAttributes(
    TutorialV3ScopedFaceAttributes attributes,
  ) => <String, Object?>{
    if (attributes.faceShape != null)
      'face_shape': _faceShapes.reverseOf(attributes.faceShape!),
    if (attributes.skinTone != null)
      'skin_tone': _skinTones.reverseOf(attributes.skinTone!),
    if (attributes.undertone != null)
      'undertone': _undertones.reverseOf(attributes.undertone!),
    if (attributes.eyeShape != null)
      'eye_shape': _eyeShapes.reverseOf(attributes.eyeShape!),
    if (attributes.lipShape != null)
      'lip_shape': _lipShapes.reverseOf(attributes.lipShape!),
  };

  static TutorialV3ScopedFaceAttributes _decodeAttributes(
    Map<String, Object?> data,
  ) => TutorialV3ScopedFaceAttributes(
    faceShape: _enumOrNull(data, 'face_shape', _faceShapes),
    skinTone: _enumOrNull(data, 'skin_tone', _skinTones),
    undertone: _enumOrNull(data, 'undertone', _undertones),
    eyeShape: _enumOrNull(data, 'eye_shape', _eyeShapes),
    lipShape: _enumOrNull(data, 'lip_shape', _lipShapes),
  );

  // These codes match `face_analysis_dto.dart` exactly. The attributes are
  // read from a persisted analysis, so a second spelling here would make a
  // stored step unreadable against its own analysis.
  static const _faceShapes = <String, FaceShape>{
    'oval': FaceShape.oval,
    'round': FaceShape.round,
    'square': FaceShape.square,
    'heart': FaceShape.heart,
    'oblong': FaceShape.oblong,
    'diamond': FaceShape.diamond,
    'triangle': FaceShape.triangle,
  };
  static const _skinTones = <String, SkinTone>{
    'very_light': SkinTone.veryLight,
    'light': SkinTone.light,
    'medium': SkinTone.medium,
    'tan': SkinTone.tan,
    'deep': SkinTone.deep,
    'very_deep': SkinTone.veryDeep,
  };
  static const _undertones = <String, Undertone>{
    'warm': Undertone.warm,
    'cool': Undertone.cool,
    'neutral': Undertone.neutral,
    'olive': Undertone.olive,
  };
  static const _eyeShapes = <String, EyeShape>{
    'almond': EyeShape.almond,
    'round': EyeShape.round,
    'hooded': EyeShape.hooded,
    'monolid': EyeShape.monolid,
    'upturned': EyeShape.upturned,
    'downturned': EyeShape.downturned,
    'deep_set': EyeShape.deepSet,
    'protruding': EyeShape.protruding,
  };
  static const _lipShapes = <String, LipShape>{
    'thin': LipShape.thin,
    'medium': LipShape.medium,
    'full': LipShape.full,
    'heart_shaped': LipShape.heartShaped,
    'wide': LipShape.wide,
    'round': LipShape.round,
  };

  static T? _enumOrNull<T>(
    Map<String, Object?> data,
    String key,
    Map<String, T> values,
  ) {
    final raw = data[key];
    if (raw == null) return null;
    if (raw is! String || !values.containsKey(raw)) {
      throw FormatException('$key contains an unsupported value: $raw');
    }
    return values[raw];
  }

  static T _lookup<T>(T? value, String key, Object? raw) {
    if (value == null) {
      throw FormatException('$key contains an unsupported value: $raw');
    }
    return value;
  }

  static String _string(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a non-empty string.');
    }
    return value;
  }

  static String? _optionalString(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a non-empty string when present.');
    }
    return value;
  }

  static int _int(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw FormatException('$key must be an integer.');
  }

  static Map<String, Object?> _map(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is! Map) throw FormatException('$key must be an object.');
    return value.cast<String, Object?>();
  }

  static List<String> _stringList(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is! List) throw FormatException('$key must be a list.');
    return value.map((entry) {
      if (entry is! String || entry.trim().isEmpty) {
        throw FormatException('$key contains a blank entry.');
      }
      return entry;
    }).toList(growable: false);
  }
}

extension _ReverseLookup<T> on Map<String, T> {
  String reverseOf(T value) {
    for (final entry in entries) {
      if (entry.value == value) return entry.key;
    }
    throw ArgumentError.value(value, 'value', 'has no persisted code');
  }
}
