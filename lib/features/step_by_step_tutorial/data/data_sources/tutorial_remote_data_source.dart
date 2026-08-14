import '../../../../core/data/supabase_remote_data_source.dart';

abstract interface class TutorialRemoteDataSource {
  String? get currentUserId;

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

  Future<String> createSignedUrl(String storagePath);
}

class SupabaseTutorialRemoteDataSource extends SupabaseRemoteDataSource
    implements TutorialRemoteDataSource {
  const SupabaseTutorialRemoteDataSource(super.client);

  static const _sessionsTable = 'tutorial_sessions';
  static const _stepsTable = 'tutorial_steps';

  @override
  String? get currentUserId => client.auth.currentUser?.id;

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
        .order('step_number'),
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
  Future<String> createSignedUrl(String storagePath) =>
      client.storage.from('face-images').createSignedUrl(storagePath, 3600);

  static List<Map<String, Object?>> _rows(List<dynamic> rows) =>
      rows.map((row) => _row(row as Map)).toList();

  static Map<String, Object?> _row(Map row) =>
      row.map((key, value) => MapEntry(key.toString(), value));
}
