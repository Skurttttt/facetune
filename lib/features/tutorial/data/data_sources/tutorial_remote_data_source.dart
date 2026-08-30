import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_remote_data_source.dart';

/// A sanitized server failure. Never carries prompts, model output, or raw
/// PostgREST detail to the presentation layer.
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

abstract interface class TutorialRemoteDataSource {
  String? get currentUserId;

  Future<Object?> analyzeManifest({
    required String previewId,
    required bool isMyMakeupKit,
  });

  Future<Map<String, Object?>?> fetchSession({
    required String previewId,
    required bool isMyMakeupKit,
  });

  Future<Map<String, Object?>?> fetchSessionById(String sessionId);

  Future<List<Object?>> fetchManifestItems(String sessionId);

  Future<List<Object?>> fetchSteps(String sessionId);

  /// Inserts the missing step records.
  ///
  /// Must tolerate a concurrent insert of the same category: the database's
  /// unique (session, category) constraint is what actually prevents
  /// duplicates, and losing that race is a success, not an error.
  Future<void> insertSteps(List<Map<String, Object?>> rows);

  Future<Map<String, Object?>?> fetchPreview({
    required String previewId,
    required bool isMyMakeupKit,
  });

  Future<Map<String, Object?>?> fetchRecommendation({
    required String recommendationId,
    required bool isMyMakeupKit,
  });

  /// Requests one guideline. The server enforces its own duplicate protection;
  /// this is the last line, not the only one.
  Future<Object?> generateStep({
    required String tutorialSessionId,
    required String category,
  });

  /// Signs a private guideline path for display. Short-lived and never stored.
  Future<String> createSignedUrl(String storagePath);

  Future<void> deleteSession(String sessionId);
}

class SupabaseTutorialRemoteDataSource extends SupabaseRemoteDataSource
    implements TutorialRemoteDataSource {
  const SupabaseTutorialRemoteDataSource(super.client);

  static const _sessionColumns =
      'id,user_id,analysis_id,source_mode,recommendation_id,'
      'kit_recommendation_id,canonical_generated_image_id,'
      'canonical_kit_generated_image_id,status,manifest_status,manifest_model,'
      'manifest_prompt_version,manifest_schema_version,manifest_created_at,'
      'tutorial_model,tutorial_prompt_version,tutorial_resolution,created_at,'
      'updated_at,completed_at';
  static const _stepColumns =
      'id,tutorial_session_id,category,position,status,guideline_storage_path,'
      'model_name,output_resolution,prompt_version,generation_attempt,'
      'failure_code,created_at,updated_at';

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  String _previewColumn(bool isMyMakeupKit) => isMyMakeupKit
      ? 'canonical_kit_generated_image_id'
      : 'canonical_generated_image_id';

  @override
  Future<Object?> analyzeManifest({
    required String previewId,
    required bool isMyMakeupKit,
  }) async {
    try {
      final response = await client.functions.invoke(
        'analyze-tutorial-manifest-v4',
        body: <String, String>{
          if (isMyMakeupKit)
            'kitGeneratedImageId': previewId
          else
            'generatedImageId': previewId,
        },
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
            'This tutorial could not be prepared.',
        retryable: payload['retryable'] == true,
      );
    }
  }

  @override
  Future<Map<String, Object?>?> fetchSession({
    required String previewId,
    required bool isMyMakeupKit,
  }) async {
    final row = await client
        .from('tutorial_v4_sessions')
        .select(_sessionColumns)
        .eq(_previewColumn(isMyMakeupKit), previewId)
        .maybeSingle();
    return row;
  }

  @override
  Future<Map<String, Object?>?> fetchSessionById(String sessionId) => client
      .from('tutorial_v4_sessions')
      .select(_sessionColumns)
      .eq('id', sessionId)
      .maybeSingle();

  @override
  Future<List<Object?>> fetchManifestItems(String sessionId) async =>
      await client
          .from('tutorial_v4_manifest_items')
          .select('category,position,presence,visual_confidence,product_backed')
          .eq('tutorial_session_id', sessionId)
          .order('position', ascending: true);

  @override
  Future<List<Object?>> fetchSteps(String sessionId) async => await client
      .from('tutorial_v4_steps')
      .select(_stepColumns)
      .eq('tutorial_session_id', sessionId)
      .order('position', ascending: true);

  @override
  Future<void> insertSteps(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return;
    // ignoreDuplicates makes a lost creation race a no-op rather than an error.
    // Two devices opening the same tutorial at once must converge on one set of
    // rows, and the database's unique (session, category) constraint is what
    // decides the winner.
    await client
        .from('tutorial_v4_steps')
        .upsert(
          rows,
          onConflict: 'tutorial_session_id,category',
          ignoreDuplicates: true,
        );
  }

  @override
  Future<Map<String, Object?>?> fetchPreview({
    required String previewId,
    required bool isMyMakeupKit,
  }) => client
      .from(isMyMakeupKit ? 'kit_generated_images' : 'generated_images')
      .select(
        isMyMakeupKit
            ? 'id,analysis_id,kit_recommendation_id'
            : 'id,analysis_id,recommendation_id',
      )
      .eq('id', previewId)
      .maybeSingle();

  @override
  Future<Map<String, Object?>?> fetchRecommendation({
    required String recommendationId,
    required bool isMyMakeupKit,
  }) => client
      .from(isMyMakeupKit ? 'kit_makeup_recommendations' : 'recommendations')
      .select(
        isMyMakeupKit
            ? 'id,analysis_id,makeup_style,model_name,prompt_version,'
                  'created_at,product_snapshot_json'
            : 'id,analysis_id,makeup_style,model_name,prompt_version,created_at',
      )
      .eq('id', recommendationId)
      .maybeSingle();

  @override
  Future<Object?> generateStep({
    required String tutorialSessionId,
    required String category,
  }) async {
    try {
      final response = await client.functions.invoke(
        "generate-tutorial-step-v4",
        body: <String, String>{
          "tutorialSessionId": tutorialSessionId,
          "category": category,
        },
      );
      return response.data;
    } on FunctionException catch (error) {
      final details = error.details;
      final root = details is Map
          ? details.map((key, value) => MapEntry(key.toString(), value))
          : const <String, Object?>{};
      final nested = root["error"];
      final payload = nested is Map
          ? nested.map((key, value) => MapEntry(key.toString(), value))
          : root;
      throw TutorialRemoteFailure(
        status: error.status,
        code: payload["code"]?.toString() ?? "",
        message:
            payload["message"]?.toString() ??
            "This tutorial step could not be prepared.",
        retryable: payload["retryable"] == true,
      );
    }
  }

  @override
  Future<String> createSignedUrl(String storagePath) =>
      client.storage.from("face-images").createSignedUrl(storagePath, 3600);

  @override
  Future<void> deleteSession(String sessionId) async {
    await client.from('tutorial_v4_sessions').delete().eq('id', sessionId);
  }
}
