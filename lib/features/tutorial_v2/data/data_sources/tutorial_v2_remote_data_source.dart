import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_remote_data_source.dart';
import '../models/tutorial_v2_session_dto.dart';

abstract interface class TutorialV2RemoteDataSource {
  String? get currentUserId;

  Future<Map<String, Object?>?> findSessionByCanonical({
    required String canonicalImageId,
    required bool isKit,
    required int planVersion,
  });

  Future<Map<String, Object?>?> findSessionById(String sessionId);

  Future<Map<String, Object?>> insertSession(Map<String, Object?> values);

  Future<Map<String, Object?>> updateSession({
    required String sessionId,
    required Map<String, Object?> values,
  });

  Future<Map<String, Object?>?> findAnalysis(String analysisId);

  Future<List<Map<String, Object?>>> selectSteps(String sessionId);

  Future<void> deleteSteps(String sessionId);

  Future<List<Map<String, Object?>>> insertSteps(
    List<Map<String, Object?>> rows,
  );

  Future<Map<String, Object?>> updateStep({
    required String stepId,
    required Map<String, Object?> values,
  });

  Future<String> createSignedUrl(String storagePath);

  /// Asks the server to generate the guideline asset for one step.
  ///
  /// The client sends only the session id and step index — every storage path
  /// and every ownership decision is derived server-side.
  Future<Object?> invokeGuideline({
    required String sessionId,
    required int stepIndex,
  });
}

class TutorialV2RemoteFailure implements Exception {
  const TutorialV2RemoteFailure({
    required this.status,
    required this.message,
    required this.retryable,
  });

  final int status;
  final String message;
  final bool retryable;
}

class SupabaseTutorialV2RemoteDataSource extends SupabaseRemoteDataSource
    implements TutorialV2RemoteDataSource {
  const SupabaseTutorialV2RemoteDataSource(super.client);

  static const _sessions = 'tutorial_v2_sessions';
  static const _steps = 'tutorial_v2_steps';

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  Future<Map<String, Object?>?> findSessionByCanonical({
    required String canonicalImageId,
    required bool isKit,
    required int planVersion,
  }) => _guard(() async {
    final column = isKit
        ? 'canonical_kit_generated_image_id'
        : 'canonical_generated_image_id';
    final row = await client
        .from(_sessions)
        .select(TutorialV2SessionDto.sessionColumns)
        .eq(column, canonicalImageId)
        .eq('plan_version', planVersion)
        .maybeSingle();
    return row == null ? null : _row(row);
  });

  @override
  Future<Map<String, Object?>?> findSessionById(String sessionId) =>
      _guard(() async {
        final row = await client
            .from(_sessions)
            .select(TutorialV2SessionDto.sessionColumns)
            .eq('id', sessionId)
            .maybeSingle();
        return row == null ? null : _row(row);
      });

  @override
  Future<Map<String, Object?>> insertSession(Map<String, Object?> values) =>
      _guard(() async {
        final row = await client
            .from(_sessions)
            .insert(values)
            .select(TutorialV2SessionDto.sessionColumns)
            .single();
        return _row(row);
      });

  @override
  Future<Map<String, Object?>> updateSession({
    required String sessionId,
    required Map<String, Object?> values,
  }) => _guard(() async {
    final row = await client
        .from(_sessions)
        .update(values)
        .eq('id', sessionId)
        .select(TutorialV2SessionDto.sessionColumns)
        .single();
    return _row(row);
  });

  @override
  Future<Map<String, Object?>?> findAnalysis(String analysisId) =>
      _guard(() async {
        final row = await client
            .from('analyses')
            .select(TutorialV2SessionDto.analysisColumns)
            .eq('id', analysisId)
            .maybeSingle();
        return row == null ? null : _row(row);
      });

  @override
  Future<List<Map<String, Object?>>> selectSteps(String sessionId) =>
      _guard(() async {
        final rows = await client
            .from(_steps)
            .select(TutorialV2SessionDto.stepColumns)
            .eq('tutorial_v2_session_id', sessionId)
            .order('step_index', ascending: true);
        return _rows(rows);
      });

  @override
  Future<void> deleteSteps(String sessionId) => _guard(() async {
    await client.from(_steps).delete().eq('tutorial_v2_session_id', sessionId);
  });

  @override
  Future<List<Map<String, Object?>>> insertSteps(
    List<Map<String, Object?>> rows,
  ) => _guard(() async {
    final inserted = await client
        .from(_steps)
        .insert(rows)
        .select(TutorialV2SessionDto.stepColumns);
    return _rows(inserted);
  });

  @override
  Future<Map<String, Object?>> updateStep({
    required String stepId,
    required Map<String, Object?> values,
  }) => _guard(() async {
    final row = await client
        .from(_steps)
        .update(values)
        .eq('id', stepId)
        .select(TutorialV2SessionDto.stepColumns)
        .single();
    return _row(row);
  });

  @override
  Future<String> createSignedUrl(String storagePath) => _guard(
    () => client.storage.from('face-images').createSignedUrl(storagePath, 3600),
  );

  @override
  Future<Object?> invokeGuideline({
    required String sessionId,
    required int stepIndex,
  }) async {
    try {
      final response = await client.functions.invoke(
        'generate-tutorial-v2-guideline',
        body: {'tutorialSessionId': sessionId, 'stepIndex': stepIndex},
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
      throw TutorialV2RemoteFailure(
        status: error.status,
        message:
            payload['message']?.toString() ??
            'The guideline could not be generated.',
        retryable: payload['retryable'] == true,
      );
    }
  }

  Map<String, Object?> _row(Map<String, dynamic> row) =>
      row.map((key, value) => MapEntry(key, value as Object?));

  List<Map<String, Object?>> _rows(List<dynamic> rows) => rows
      .map((row) => _row((row as Map).cast<String, dynamic>()))
      .toList(growable: false);

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (error) {
      final status = int.tryParse(error.code ?? '') ?? 0;
      throw TutorialV2RemoteFailure(
        status: status,
        message: error.message,
        // 5xx and transport-level failures are worth retrying; a constraint
        // violation is not.
        retryable: status == 0 || status >= 500,
      );
    } on StorageException catch (error) {
      throw TutorialV2RemoteFailure(
        status: int.tryParse(error.statusCode ?? '') ?? 0,
        message: error.message,
        retryable: true,
      );
    }
  }
}
