import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_remote_data_source.dart';

abstract interface class TutorialRemoteDataSource {
  String? get currentUserId;

  /// Invokes `generate-tutorial-step` (ST-9) for [tutorialStepId], returning
  /// its raw JSON payload (`{step: <tutorial_steps row>}`) for
  /// `TutorialStepDto.fromResponse` to parse. Throws [TutorialRemoteFailure]
  /// on any non-2xx response.
  Future<Object?> invoke({required String tutorialStepId});

  /// Finds a session by its unique source key (see
  /// `tutorial_sessions_recommendation_variation_unique` /
  /// `tutorial_sessions_kit_recommendation_variation_unique`). Exactly one
  /// of [recommendationId] / [kitRecommendationId] must be provided.
  Future<Map<String, Object?>?> findSession({
    required String sourceModeCode,
    required String analysisId,
    String? recommendationId,
    String? kitRecommendationId,
    required int generationNumber,
  });

  Future<Map<String, Object?>> insertSession(Map<String, Object?> values);

  Future<Map<String, Object?>> updateSession(
    String sessionId,
    Map<String, Object?> values,
  );

  Future<List<Map<String, Object?>>> selectSteps(String tutorialSessionId);

  Future<Map<String, Object?>> insertStep(Map<String, Object?> values);

  Future<Map<String, Object?>> updateStep(
    String stepId,
    Map<String, Object?> values,
  );

  /// Applies [values] to every step of [tutorialSessionId] except rows
  /// whose `category` equals [excludedCategoryCode], in one bulk UPDATE —
  /// see `TutorialRepository.resetForRegeneration` (ST-12). This data
  /// source stays generic (plain column values, no DTO/domain knowledge,
  /// matching every other method here); the repository decides what
  /// [values] and [excludedCategoryCode] mean.
  Future<void> resetSteps({
    required String tutorialSessionId,
    required Map<String, Object?> values,
    required String excludedCategoryCode,
  });

  Future<String> createSignedUrl(String storagePath);
}

/// Mirrors `PreviewRemoteFailure` — see
/// `preview/data/data_sources/preview_remote_data_source.dart`.
class TutorialRemoteFailure implements Exception {
  const TutorialRemoteFailure({
    required this.status,
    required this.code,
    required this.message,
    required this.retryable,
  });

  final int status;
  final String code;
  final String message;
  final bool retryable;
}

class SupabaseTutorialRemoteDataSource extends SupabaseRemoteDataSource
    implements TutorialRemoteDataSource {
  const SupabaseTutorialRemoteDataSource(super.client);

  static const _sessionsTable = 'tutorial_sessions';
  static const _stepsTable = 'tutorial_steps';

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  Future<Object?> invoke({required String tutorialStepId}) async {
    try {
      final response = await client.functions.invoke(
        'generate-tutorial-step',
        body: {'tutorialStepId': tutorialStepId},
      );
      return response.data;
    } on FunctionException catch (error) {
      final details = error.details;
      final root = details is Map
          ? details.map((key, value) => MapEntry(key.toString(), value))
          : const <String, Object?>{};
      final nested = root['error'];
      final payload = nested is Map
          ? nested.map((key, value) => MapEntry(key.toString(), value))
          : root;
      throw TutorialRemoteFailure(
        status: error.status,
        code: payload['code']?.toString() ?? '',
        message:
            payload['message']?.toString() ??
            'This step could not be generated.',
        retryable: payload['retryable'] == true,
      );
    }
  }

  @override
  Future<Map<String, Object?>?> findSession({
    required String sourceModeCode,
    required String analysisId,
    String? recommendationId,
    String? kitRecommendationId,
    required int generationNumber,
  }) async {
    var query = client
        .from(_sessionsTable)
        .select('*')
        .eq('source_mode', sourceModeCode)
        .eq('analysis_id', analysisId)
        .eq('generation_number', generationNumber);
    query = recommendationId != null
        ? query.eq('recommendation_id', recommendationId)
        : query.eq('kit_recommendation_id', kitRecommendationId!);
    final row = await query.maybeSingle();
    return row == null ? null : _row(row);
  }

  @override
  Future<Map<String, Object?>> insertSession(
    Map<String, Object?> values,
  ) async => _row(
    await client.from(_sessionsTable).insert(values).select('*').single(),
  );

  @override
  Future<Map<String, Object?>> updateSession(
    String sessionId,
    Map<String, Object?> values,
  ) async => _row(
    await client
        .from(_sessionsTable)
        .update(values)
        .eq('id', sessionId)
        .select('*')
        .single(),
  );

  @override
  Future<List<Map<String, Object?>>> selectSteps(
    String tutorialSessionId,
  ) async => _rows(
    await client
        .from(_stepsTable)
        .select('*')
        .eq('tutorial_session_id', tutorialSessionId)
        .order('step_number', ascending: true),
  );

  @override
  Future<Map<String, Object?>> insertStep(Map<String, Object?> values) async =>
      _row(await client.from(_stepsTable).insert(values).select('*').single());

  @override
  Future<Map<String, Object?>> updateStep(
    String stepId,
    Map<String, Object?> values,
  ) async => _row(
    await client
        .from(_stepsTable)
        .update(values)
        .eq('id', stepId)
        .select('*')
        .single(),
  );

  @override
  Future<void> resetSteps({
    required String tutorialSessionId,
    required Map<String, Object?> values,
    required String excludedCategoryCode,
  }) async {
    await client
        .from(_stepsTable)
        .update(values)
        .eq('tutorial_session_id', tutorialSessionId)
        .neq('category', excludedCategoryCode);
  }

  @override
  Future<String> createSignedUrl(String storagePath) =>
      client.storage.from('face-images').createSignedUrl(storagePath, 3600);

  static List<Map<String, Object?>> _rows(List<dynamic> rows) =>
      rows.map((row) => _row(row as Map)).toList();

  static Map<String, Object?> _row(Map row) =>
      row.map((key, value) => MapEntry(key.toString(), value));
}
