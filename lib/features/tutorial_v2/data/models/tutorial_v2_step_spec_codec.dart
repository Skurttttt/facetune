import '../../../makeup_kit/domain/entities/foundation_depth.dart';
import '../../../makeup_kit/domain/entities/foundation_undertone.dart';
import '../../../makeup_kit/domain/entities/makeup_kit_finish.dart';
import '../../../makeup_kit/domain/value_objects/normalized_hex_color.dart';
import '../../domain/entities/tutorial_v2_category.dart';
import '../../domain/entities/tutorial_v2_product_snapshot.dart';
import '../../domain/entities/tutorial_v2_step_spec.dart';

/// Serializes the *authored* half of a step and nothing else.
///
/// A step's guideline and result instructions are derived from its authored
/// fields (see `TutorialV2GuidelineInstruction.derive`), so persisting them
/// would create a second copy that could drift from the text on reload —
/// exactly what the single-source-per-step rule forbids. Instead the codec
/// round-trips a [TutorialV2StepDraft], and `TutorialV2Plan.fromDrafts`
/// re-derives the instructions and the cumulative category state when the
/// plan is rebuilt. The invariant therefore survives persistence by
/// construction rather than by careful writing.
///
/// [schemaVersion] is the shape of this JSON payload, which is separate from
/// `TutorialV2PlanVersion` (the shape of the plan as a whole).
abstract final class TutorialV2StepSpecCodec {
  static const schemaVersion = 1;

  static Map<String, Object?> encode(TutorialV2StepSpec step) => encodeDraft(
    TutorialV2StepDraft(
      category: step.category,
      title: step.title,
      whatToApply: step.whatToApply,
      whereToApply: step.whereToApply,
      direction: step.direction,
      technique: step.technique,
      intensity: step.intensity,
      faceRationale: step.faceRationale,
      targetLookCues: step.targetLookCues,
      amount: step.amount,
      toolSuggestion: step.toolSuggestion,
      personalizedTip: step.personalizedTip,
      avoid: step.avoid,
      productSnapshot: step.productSnapshot,
    ),
  );

  /// Encodes the authored fields. The product snapshot is persisted in its
  /// own column, so it is deliberately absent here.
  static Map<String, Object?> encodeDraft(TutorialV2StepDraft draft) => {
    'schema': schemaVersion,
    'category': draft.category.code,
    'title': draft.title,
    'whatToApply': draft.whatToApply,
    'whereToApply': draft.whereToApply,
    'direction': draft.direction,
    'technique': draft.technique,
    'intensity': draft.intensity,
    'faceRationale': draft.faceRationale,
    'targetLookCues': draft.targetLookCues,
    'amount': draft.amount,
    'toolSuggestion': draft.toolSuggestion,
    'personalizedTip': draft.personalizedTip,
    'avoid': draft.avoid,
  };

  /// Rebuilds the authored draft.
  ///
  /// [productSnapshot] comes from the row's own `product_snapshot_json`
  /// column rather than from [payload].
  ///
  /// Throws [FormatException] on any malformed payload so a corrupt row is
  /// reported as stale rather than silently producing a half-empty step.
  static TutorialV2StepDraft decodeDraft(
    Object? payload, {
    TutorialV2ProductSnapshot? productSnapshot,
  }) {
    final map = _object(payload, 'step spec');

    final schema = map['schema'];
    if (schema is! int || schema > schemaVersion) {
      throw FormatException('Unsupported step spec schema: $schema.');
    }

    final categoryCode = _string(map, 'category');
    final category = TutorialV2Category.fromCode(categoryCode);
    if (category == null) {
      throw FormatException('Unknown step category "$categoryCode".');
    }

    return TutorialV2StepDraft(
      category: category,
      title: _string(map, 'title'),
      whatToApply: _string(map, 'whatToApply'),
      whereToApply: _string(map, 'whereToApply'),
      direction: _string(map, 'direction'),
      technique: _string(map, 'technique'),
      intensity: _string(map, 'intensity'),
      faceRationale: _string(map, 'faceRationale'),
      targetLookCues: _string(map, 'targetLookCues'),
      amount: _nullableString(map['amount']),
      toolSuggestion: _nullableString(map['toolSuggestion']),
      personalizedTip: _nullableString(map['personalizedTip']),
      avoid: _nullableString(map['avoid']),
      productSnapshot: productSnapshot,
    );
  }

  static Map<String, Object?>? encodeProduct(
    TutorialV2ProductSnapshot? snapshot,
  ) {
    if (snapshot == null) return null;
    return {
      'productId': snapshot.productId,
      'category': snapshot.category.code,
      'colorHex': snapshot.color.value,
      'finish': snapshot.finish.code,
      'productName': snapshot.productName,
      'colorLabel': snapshot.colorLabel,
      'foundationDepth': snapshot.foundationDepth?.code,
      'foundationUndertone': snapshot.foundationUndertone?.code,
    };
  }

  static TutorialV2ProductSnapshot? decodeProduct(Object? payload) {
    if (payload == null) return null;
    final map = _object(payload, 'product snapshot');

    final categoryCode = _string(map, 'category');
    final category = TutorialV2Category.fromCode(categoryCode);
    if (category == null || category.isFinalLook) {
      throw FormatException('Invalid product category "$categoryCode".');
    }

    final finishCode = _string(map, 'finish');
    final finish = MakeupKitFinish.fromCode(finishCode);
    if (finish == null) {
      throw FormatException('Unknown product finish "$finishCode".');
    }

    final color = NormalizedHexColor.tryParse(_string(map, 'colorHex'));
    if (color == null) {
      throw const FormatException('Product colorHex is invalid.');
    }

    return TutorialV2ProductSnapshot(
      productId: _string(map, 'productId'),
      category: category,
      color: color,
      finish: finish,
      productName: _nullableString(map['productName']),
      colorLabel: _nullableString(map['colorLabel']),
      foundationDepth: _nullableEnum(
        map['foundationDepth'],
        FoundationDepth.fromCode,
        'foundationDepth',
      ),
      foundationUndertone: _nullableEnum(
        map['foundationUndertone'],
        FoundationUndertone.fromCode,
        'foundationUndertone',
      ),
    );
  }

  static Map<String, Object?> _object(Object? value, String label) {
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    throw FormatException('$label must be an object.');
  }

  static String _string(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value;
    throw FormatException('$key must be a non-empty string.');
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    if (value is String && value.trim().isNotEmpty) return value;
    throw const FormatException('Optional fields must be non-blank strings.');
  }

  static T? _nullableEnum<T>(
    Object? value,
    T? Function(String) fromCode,
    String label,
  ) {
    if (value == null) return null;
    if (value is! String) throw FormatException('$label must be a string.');
    final parsed = fromCode(value);
    if (parsed == null) throw FormatException('Unknown $label "$value".');
    return parsed;
  }
}
