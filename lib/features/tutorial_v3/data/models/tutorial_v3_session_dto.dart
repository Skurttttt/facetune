import '../../domain/entities/tutorial_v3_canonical_preview.dart';
import '../../domain/entities/tutorial_v3_category.dart';
import '../../domain/entities/tutorial_v3_geometry.dart';
import '../../domain/entities/tutorial_v3_geometry_status.dart';
import '../../domain/entities/tutorial_v3_session.dart';
import '../../domain/entities/tutorial_v3_session_snapshot.dart';
import '../../domain/entities/tutorial_v3_session_status.dart';
import '../../domain/entities/tutorial_v3_source_mode.dart';
import '../../domain/entities/tutorial_v3_step.dart';
import '../../domain/errors/tutorial_v3_failure.dart';
import '../../domain/validation/tutorial_v3_geometry_validator.dart';
import '../../domain/value_objects/tutorial_v3_plan_version.dart';
import 'tutorial_v3_step_spec_codec.dart';

/// Maps `tutorial_v3_sessions` / `tutorial_v3_steps` rows onto the domain.
///
/// Reading is strict. `plan_version` is parsed rather than assumed, so a row
/// written by a future build is rejected instead of being reinterpreted as a
/// V3 plan.
abstract final class TutorialV3SessionDto {
  static TutorialV3SessionSnapshot fromRows({
    required Map<String, Object?> session,
    required List<Map<String, Object?>> steps,
  }) {
    // The plan version is checked before anything else is decoded. A row from
    // V1, V2 or a newer build carries Step Specs written to a schema this
    // build does not know, so decoding them would either throw deep inside a
    // field parser or, worse, succeed by coincidence. Refusing up front is
    // what keeps "V3 must not silently interpret a V1/V2 row" true.
    final planVersion = _int(session, 'plan_version');
    if (!TutorialV3PlanVersion.isSupported(planVersion)) {
      return TutorialV3IncompatibleSession(
        sessionId: _string(session, 'id'),
        persistedPlanVersion: planVersion,
      );
    }

    final sorted = [...steps]
      ..sort((a, b) => _int(a, 'step_index').compareTo(_int(b, 'step_index')));
    return TutorialV3LoadedSession(
      session: sessionFromRow(session),
      steps: sorted.map(stepFromRow).toList(growable: false),
    );
  }

  static TutorialV3Session sessionFromRow(Map<String, Object?> row) {
    final sourceMode = _required(
      TutorialV3SourceMode.fromCode(_string(row, 'source_mode')),
      'source_mode',
      row['source_mode'],
    );
    final standardImageId = _optionalString(
      row,
      'canonical_generated_image_id',
    );
    final kitImageId = _optionalString(
      row,
      'canonical_kit_generated_image_id',
    );
    final canonicalImageId = sourceMode.isKit ? kitImageId : standardImageId;
    if (canonicalImageId == null) {
      throw FormatException(
        'A ${sourceMode.code} session must reference a canonical preview.',
      );
    }

    return TutorialV3Session(
      id: _string(row, 'id'),
      userId: _string(row, 'user_id'),
      analysisId: _string(row, 'analysis_id'),
      sourceMode: sourceMode,
      recommendationId: _optionalString(row, 'recommendation_id'),
      kitRecommendationId: _optionalString(row, 'kit_recommendation_id'),
      selectedStyleCode: _string(row, 'makeup_style'),
      canonicalPreview: TutorialV3CanonicalPreview(
        generatedImageId: canonicalImageId,
        storagePath: _string(row, 'canonical_image_path'),
        sourceMode: sourceMode,
      ),
      totalSteps: _int(row, 'total_steps'),
      planVersion: TutorialV3PlanVersion.parse(_int(row, 'plan_version')),
      status: _required(
        TutorialV3SessionStatus.fromCode(_string(row, 'status')),
        'status',
        row['status'],
      ),
      createdAt: _dateTime(row, 'created_at'),
      updatedAt: _dateTime(row, 'updated_at'),
    );
  }

  static TutorialV3Step stepFromRow(Map<String, Object?> row) {
    final snapshot = row['product_snapshot_json'];
    final spec = TutorialV3StepSpecCodec.decode(
      spec: _map(row, 'step_spec_json'),
      productSnapshot: snapshot is Map ? snapshot.cast<String, Object?>() : null,
    );
    final schemaVersion = row['geometry_schema_version'] == null
        ? null
        : _int(row, 'geometry_schema_version');

    return TutorialV3Step(
      spec: spec,
      geometryStatus: _required(
        TutorialV3GeometryStatus.fromCode(_string(row, 'geometry_status')),
        'geometry_status',
        row['geometry_status'],
      ),
      geometry: _geometry(row, spec.category, schemaVersion),
      geometrySchemaVersion: schemaVersion,
      attemptCount: _intOr(row, 'attempt_count', 0),
      lastErrorCode: _optionalString(row, 'geometry_error'),
    );
  }

  /// Decodes stored geometry, or returns `null` when it cannot be rendered.
  ///
  /// Two cases yield `null` rather than an exception, because neither should
  /// make an entire tutorial unopenable:
  ///
  /// * a document written against a different schema version — the step is
  ///   surfaced as stale (`hasStaleGeometry`) and can simply be re-mapped;
  /// * a document that fails validation — the step behaves as unmapped, which
  ///   is exactly the "a missing overlay beats a wrong one" rule.
  ///
  /// The validator itself stays strict: nothing invalid is ever returned as
  /// usable geometry.
  static TutorialV3Geometry? _geometry(
    Map<String, Object?> row,
    TutorialV3Category category,
    int? schemaVersion,
  ) {
    final raw = row['geometry_json'];
    if (raw is! Map) return null;
    if (schemaVersion != tutorialV3GeometrySchemaVersion) return null;
    try {
      return TutorialV3GeometryValidator.validate(
        raw.cast<String, Object?>(),
        expectedCategory: category,
      );
    } on TutorialV3Failure {
      return null;
    }
  }

  static T _required<T>(T? value, String key, Object? raw) {
    if (value == null) {
      throw FormatException('$key contains an unsupported value: $raw');
    }
    return value;
  }

  static String _string(Map<String, Object?> row, String key) {
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

  static int _int(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw FormatException('$key must be an integer.');
  }

  static int _intOr(Map<String, Object?> row, String key, int fallback) =>
      row[key] == null ? fallback : _int(row, key);

  static Map<String, Object?> _map(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is! Map) throw FormatException('$key must be an object.');
    return value.cast<String, Object?>();
  }

  static DateTime _dateTime(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw FormatException('$key must be a timestamp.');
  }
}
