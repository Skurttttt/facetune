import '../../domain/entities/tutorial_generation_status.dart';
import '../../domain/entities/tutorial_session.dart';
import '../../domain/entities/tutorial_source_mode.dart';
import '../../domain/entities/tutorial_step.dart';

/// Maps between raw `tutorial_sessions` Supabase rows and the
/// [TutorialSession] domain entity.
///
/// Every raw value is defensively re-validated here — a database row is
/// untrusted input, even though the columns are also constrained at the
/// schema level
/// (`supabase/migrations/20260814000300_tutorial_sessions_steps.sql`).
///
/// Unlike [TutorialStepDto], no async signed-URL step is needed at the
/// session level (only steps reference images directly), so this stays a
/// static-methods-only class, matching `MakeupKitProductDto`.
abstract final class TutorialSessionDto {
  /// Parses a raw row into a domain entity. [steps] must already be loaded
  /// and ordered by step number — this method does not fetch them.
  static TutorialSession fromRow(
    Map<String, Object?> row, {
    required List<TutorialStep> steps,
  }) {
    return TutorialSession(
      id: _requiredString(row, 'id'),
      userId: _requiredString(row, 'user_id'),
      sourceMode: _requiredEnum(
        row,
        'source_mode',
        TutorialSourceMode.fromCode,
      ),
      sourceAnalysisId: _requiredString(row, 'analysis_id'),
      sourceRecommendationId: _optionalString(row, 'recommendation_id'),
      sourceKitResultId: _optionalString(row, 'kit_recommendation_id'),
      styleCode: _requiredString(row, 'makeup_style'),
      generationNumber: _requiredInt(row, 'generation_number'),
      totalSteps: _requiredInt(row, 'total_steps'),
      promptVersion: _optionalString(row, 'prompt_version'),
      tutorialModel: _optionalString(row, 'tutorial_model'),
      tutorialImageSize: _optionalInt(row, 'tutorial_image_size'),
      generationStatus: _requiredEnum(
        row,
        'generation_status',
        TutorialGenerationStatus.fromCode,
      ),
      steps: steps,
      createdAt: DateTime.parse(_requiredString(row, 'created_at')).toUtc(),
      updatedAt: DateTime.parse(_requiredString(row, 'updated_at')).toUtc(),
    );
  }

  /// Column values for inserting a new session owned by [userId]. Exactly
  /// one of [recommendationId] / [kitRecommendationId] must be provided,
  /// matching [sourceMode] — enforced again at the schema level by
  /// `tutorial_sessions_source_reference_matches_mode`.
  static Map<String, Object?> toInsertRow({
    required String userId,
    required TutorialSourceMode sourceMode,
    required String analysisId,
    String? recommendationId,
    String? kitRecommendationId,
    required String styleCode,
    required int generationNumber,
    required int totalSteps,
    String? tutorialModel,
    int? tutorialImageSize,
    String? promptVersion,
  }) => {
    'user_id': userId,
    'source_mode': sourceMode.code,
    'analysis_id': analysisId,
    'recommendation_id': recommendationId,
    'kit_recommendation_id': kitRecommendationId,
    'makeup_style': styleCode,
    'generation_number': generationNumber,
    'total_steps': totalSteps,
    'tutorial_model': tutorialModel,
    'tutorial_image_size': tutorialImageSize,
    'prompt_version': promptVersion,
  };

  static Map<String, Object?> statusUpdateRow(
    TutorialGenerationStatus status,
  ) => {'generation_status': status.code};

  static String _requiredString(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a non-empty string.');
    }
    return value;
  }

  static String? _optionalString(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a non-empty string when present.');
    }
    return value;
  }

  static int _requiredInt(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is! int) throw FormatException('$key must be an integer.');
    return value;
  }

  static int? _optionalInt(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value == null) return null;
    if (value is! int) throw FormatException('$key must be an integer.');
    return value;
  }

  static T _requiredEnum<T>(
    Map<String, Object?> row,
    String key,
    T? Function(String code) fromCode,
  ) {
    final value = row[key];
    if (value is! String) throw FormatException('$key must be a string.');
    final parsed = fromCode(value);
    if (parsed == null) {
      throw FormatException('$key contains an unsupported value.');
    }
    return parsed;
  }
}
