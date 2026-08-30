import '../../../makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import '../../domain/entities/canonical_preview_ref.dart';
import '../../domain/entities/look_product_snapshot.dart';
import '../../domain/entities/recommendation_source_mode.dart';
import '../../domain/entities/tutorial_ai_configuration.dart';
import '../../domain/entities/tutorial_category.dart';
import '../../domain/entities/tutorial_manifest.dart';
import '../../domain/entities/tutorial_step.dart';
import '../../domain/entities/validated_look_plan.dart';
import '../../domain/errors/tutorial_failure.dart';

/// Parsing helpers shared by the tutorial DTOs.
///
/// Every one of these rejects rather than substitutes a default. A row whose
/// category or status is outside the controlled vocabulary is corrupt or from a
/// newer schema; coercing it to something plausible would silently build the
/// wrong tutorial.
abstract final class _Read {
  static Map<String, Object?> object(Object? value, String what) {
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    throw TutorialFailure(
      'The tutorial data could not be read.',
      kind: TutorialFailureKind.validation,
      retryable: false,
    ).withContext(what);
  }

  static String text(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is String && value.trim().isNotEmpty) return value;
    throw TutorialFailure(
      'The tutorial data could not be read.',
      kind: TutorialFailureKind.validation,
      retryable: false,
    ).withContext(key);
  }

  static String? nullableText(Map<String, Object?> row, String key) {
    final value = row[key];
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  static int integer(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw TutorialFailure(
      'The tutorial data could not be read.',
      kind: TutorialFailureKind.validation,
      retryable: false,
    ).withContext(key);
  }

  static double? nullableDouble(Map<String, Object?> row, String key) {
    final value = row[key];
    return value is num ? value.toDouble() : null;
  }

  static DateTime time(Map<String, Object?> row, String key) {
    final parsed = DateTime.tryParse(row[key]?.toString() ?? '');
    if (parsed == null) {
      throw TutorialFailure(
        'The tutorial data could not be read.',
        kind: TutorialFailureKind.validation,
        retryable: false,
      ).withContext(key);
    }
    return parsed.toUtc();
  }

  static DateTime? nullableTime(Map<String, Object?> row, String key) =>
      DateTime.tryParse(row[key]?.toString() ?? '')?.toUtc();
}

extension on TutorialFailure {
  /// Keeps the user-facing message clean while making the developer log
  /// specific about which field failed.
  TutorialFailure withContext(String what) {
    assert(() {
      // ignore: avoid_print
      print('[tutorial] Unreadable field: $what');
      return true;
    }());
    return this;
  }
}

/// Maps a `tutorial_v4_manifest_items` row set into a [TutorialManifest].
abstract final class TutorialManifestDto {
  static TutorialManifest fromRows({
    required Map<String, Object?> session,
    required List<Object?> itemRows,
    required CanonicalPreviewRef preview,
  }) {
    final items = <TutorialManifestItem>[];
    for (final raw in itemRows) {
      final row = _Read.object(raw, 'manifest item');
      final category = TutorialCategory.fromCode(_Read.text(row, 'category'));
      final presence = TutorialCategoryPresence.fromCode(
        _Read.text(row, 'presence'),
      );
      if (category == null || presence == null) {
        throw const TutorialFailure(
          'This tutorial uses a step type this app version does not support.',
          kind: TutorialFailureKind.unsupportedCategory,
          retryable: false,
        );
      }
      items.add(
        TutorialManifestItem(
          category: category,
          presence: presence,
          visualConfidence: _Read.nullableDouble(row, 'visual_confidence'),
          productBacked: row['product_backed'] == true,
        ),
      );
    }
    final status = TutorialManifestStatus.fromCode(
      _Read.text(session, 'manifest_status'),
    );
    if (status == null) {
      throw const TutorialFailure(
        'This tutorial is in a state this app version does not support.',
        kind: TutorialFailureKind.validation,
        retryable: false,
      );
    }
    return TutorialManifest(
      canonicalPreviewId: preview.id,
      sourceMode: preview.sourceMode,
      status: status,
      items: items,
      modelId: _Read.nullableText(session, 'manifest_model') ?? '',
      promptVersion:
          _Read.nullableText(session, 'manifest_prompt_version') ?? '',
      schemaVersion:
          _Read.nullableText(session, 'manifest_schema_version') ?? '',
      createdAt:
          _Read.nullableTime(session, 'manifest_created_at') ??
          _Read.time(session, 'created_at'),
    );
  }
}

/// Maps a `tutorial_v4_steps` row into a [TutorialStep].
abstract final class TutorialStepDto {
  static TutorialStep fromRow(
    Object? raw, {
    required LookProductSnapshot snapshot,
    required bool isMyMakeupKit,
  }) {
    final row = _Read.object(raw, 'tutorial step');
    final category = TutorialCategory.fromCode(_Read.text(row, 'category'));
    final status = TutorialStepStatus.fromCode(_Read.text(row, 'status'));
    if (category == null || status == null) {
      throw const TutorialFailure(
        'This tutorial uses a step type this app version does not support.',
        kind: TutorialFailureKind.unsupportedCategory,
        retryable: false,
      );
    }
    return TutorialStep(
      id: _Read.text(row, 'id'),
      sessionId: _Read.text(row, 'tutorial_session_id'),
      category: category,
      position: _Read.integer(row, 'position'),
      status: status,
      guidelineStoragePath: _Read.nullableText(row, 'guideline_storage_path'),
      modelId: _Read.nullableText(row, 'model_name'),
      outputResolution: TutorialOutputResolutionCodec.fromRow(row),
      promptVersion: _Read.nullableText(row, 'prompt_version'),
      generationAttempt: _Read.integer(row, 'generation_attempt'),
      // Linked from the immutable snapshot rather than stored on the row, so
      // the step always presents exactly the products the look was validated
      // with. Standard Mode carries none.
      productSnapshotItems: isMyMakeupKit
          ? snapshot.itemsFor(category)
          : const <LookProductSnapshotItem>[],
      failureCode: _Read.nullableText(row, 'failure_code'),
      createdAt: _Read.time(row, 'created_at'),
      updatedAt: _Read.time(row, 'updated_at'),
    );
  }
}

/// Isolated so the nullable-resolution parse is not repeated.
abstract final class TutorialOutputResolutionCodec {
  static TutorialOutputResolution? fromRow(Map<String, Object?> row) {
    final code = _Read.nullableText(row, 'output_resolution');
    return code == null ? null : TutorialOutputResolution.fromCode(code);
  }
}

/// Maps a recommendation row into the shared [ValidatedLookPlan].
abstract final class LookPlanDto {
  static ValidatedLookPlan fromRow(
    Object? raw, {
    required RecommendationSourceMode sourceMode,
  }) {
    final row = _Read.object(raw, 'look plan');
    final id = _Read.text(row, 'id');
    return ValidatedLookPlan(
      id: id,
      analysisId: _Read.text(row, 'analysis_id'),
      styleCode: _Read.text(row, 'makeup_style'),
      source: switch (sourceMode) {
        RecommendationSourceMode.standard => StandardLookPlanSource(
          recommendationId: id,
        ),
        RecommendationSourceMode.myMakeupKit => MyMakeupKitLookPlanSource(
          kitRecommendationId: id,
          productSnapshot: _snapshot(row['product_snapshot_json']),
        ),
      },
      modelId: _Read.nullableText(row, 'model_name') ?? '',
      promptVersion: _Read.nullableText(row, 'prompt_version') ?? '',
      createdAt: _Read.time(row, 'created_at'),
    );
  }

  static LookProductSnapshot _snapshot(Object? value) {
    if (value is! List) return LookProductSnapshot.empty;
    return LookProductSnapshot.fromKitSnapshots(
      value.map((raw) {
        final row = _Read.object(raw, 'product snapshot');
        return KitProductSnapshot(
          productId: _Read.text(row, 'productId'),
          category: _Read.text(row, 'category'),
          colorHex: _Read.text(row, 'colorHex'),
          finish: _Read.text(row, 'finish'),
          productName: _Read.nullableText(row, 'productName'),
          colorLabel: _Read.nullableText(row, 'colorLabel'),
          foundationDepth: _Read.nullableText(row, 'foundationDepth'),
          foundationUndertone: _Read.nullableText(row, 'foundationUndertone'),
        );
      }).toList(),
    );
  }
}
