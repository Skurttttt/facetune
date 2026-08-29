import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_remote_data_source.dart';
import '../../domain/errors/tutorial_v3_failure.dart';
import '../../domain/services/tutorial_v3_storage_paths.dart';

/// The raw persistence surface for Tutorial V3.
///
/// Deliberately row-shaped: it moves maps in and out of Postgres and does no
/// domain reasoning. Every call is subject to RLS, so a row that is not the
/// caller's is invisible rather than forbidden.
abstract interface class TutorialV3RemoteDataSource {
  String? get currentUserId;

  /// Resolves the tutorial for a premium preview, creating it if needed.
  ///
  /// Delegates to `open_tutorial_v3_session`, which derives the analysis, the
  /// recommendation, the selected style and the canonical path from rows RLS
  /// has already scoped to the caller. Returns the session id.
  ///
  /// Doing this in one SECURITY INVOKER statement is what keeps the client
  /// from choosing any of those: it names the preview and nothing else.
  Future<String> openSession({
    required String canonicalImageId,
    required bool kit,
  });

  /// Finds the session for a canonical preview, which is the natural key for
  /// a tutorial.
  ///
  /// Deliberately not filtered by plan version: a session stored under a
  /// version this build cannot read must still be found, so it can be
  /// reported as incompatible rather than silently duplicated by a second
  /// tutorial for the same target.
  Future<Map<String, Object?>?> findSessionByCanonicalImage({
    required bool kit,
    required String canonicalImageId,
  });

  Future<Map<String, Object?>?> findSessionById(String sessionId);

  Future<Map<String, Object?>> insertSession(Map<String, Object?> values);

  Future<Map<String, Object?>> updateSession(
    String sessionId,
    Map<String, Object?> values,
  );

  Future<List<Map<String, Object?>>> selectSteps(String sessionId);

  /// Writes a whole plan in one transaction via `persist_tutorial_v3_plan`.
  Future<int> persistPlan({
    required String sessionId,
    required String? plannerModel,
    required String? plannerPromptVersion,
    required List<Map<String, Object?>> steps,
  });

  /// Atomically claims one step for geometry mapping.
  ///
  /// Delegates to `claim_tutorial_v3_geometry`, which decides reuse, in-flight,
  /// exhausted, final-look and not-found in a single statement. Doing this
  /// client-side would be a read-then-write that two concurrent callers could
  /// both win.
  ///
  /// [schemaVersion] is the geometry schema THIS BUILD can interpret. The
  /// RPC reuses a stored document only when it matches, so a document from a
  /// different build is re-mapped rather than rendered.
  ///
  /// Returns the RPC's outcome object.
  Future<Map<String, Object?>> claimGeometry({
    required String sessionId,
    required int stepIndex,
    required int maxAttempts,
    required int schemaVersion,
  });

  /// Updates one step, matching on the session and step index so a step can
  /// never be updated through another session's id.
  ///
  /// Returns the updated row, or `null` when [expectedStatuses] is supplied
  /// and the step was not in one of those states.
  Future<Map<String, Object?>?> updateStep({
    required String sessionId,
    required int stepIndex,
    required Map<String, Object?> values,
    List<String>? expectedStatuses,
  });

  /// The original selfie path recorded on an analysis.
  ///
  /// Read through RLS, so an analysis that is not the caller's is invisible
  /// rather than forbidden — the tutorial simply has no image to show.
  Future<String?> findOriginalImagePath(String analysisId);

  Future<String> createSignedUrl(String storagePath);
}

class SupabaseTutorialV3RemoteDataSource extends SupabaseRemoteDataSource
    implements TutorialV3RemoteDataSource {
  const SupabaseTutorialV3RemoteDataSource(super.client);

  static const _sessions = 'tutorial_v3_sessions';
  static const _steps = 'tutorial_v3_steps';

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  Future<String> openSession({
    required String canonicalImageId,
    required bool kit,
  }) async {
    try {
      final id = await client.rpc(
        'open_tutorial_v3_session',
        params: {'p_generated_image_id': canonicalImageId, 'p_kit': kit},
      );
      return '$id';
    } on PostgrestException catch (error) {
      // Debug only, and only the SQLSTATE. `PGRST202` means the function is
      // missing from the schema cache; `42501` means RLS refused; `P0002`,
      // `28000` and `22023` are the resolver's own. The message can carry the
      // statement and its arguments, so it is not recorded.
      if (kDebugMode) {
        debugPrint(
          '[tutorial_v3] open_tutorial_v3_session rejected: '
          'code=${error.code ?? 'none'}',
        );
      }
      // The RPC raises rather than returning a status, so its codes are
      // translated here. Anything else propagates unchanged: a failure this
      // layer does not recognise must not be reported as a tidy domain error.
      throw switch (error.code) {
        'P0002' => const TutorialV3Failure(
          'The final look for this tutorial is no longer available.',
          kind: TutorialV3FailureKind.notFound,
          retryable: false,
        ),
        '28000' => const TutorialV3Failure(
          'Sign in again to open your tutorial.',
          kind: TutorialV3FailureKind.sessionExpired,
          retryable: false,
        ),
        '22023' => const TutorialV3Failure(
          'This final look cannot be used for a tutorial.',
          kind: TutorialV3FailureKind.validation,
          retryable: false,
        ),
        _ => error,
      };
    }
  }

  @override
  Future<Map<String, Object?>?> findSessionByCanonicalImage({
    required bool kit,
    required String canonicalImageId,
  }) async {
    final column = kit
        ? 'canonical_kit_generated_image_id'
        : 'canonical_generated_image_id';
    final row = await client
        .from(_sessions)
        .select()
        .eq(column, canonicalImageId)
        .order('plan_version', ascending: false)
        .limit(1)
        .maybeSingle();
    return row?.cast<String, Object?>();
  }

  @override
  Future<Map<String, Object?>?> findSessionById(String sessionId) async {
    final row = await client
        .from(_sessions)
        .select()
        .eq('id', sessionId)
        .maybeSingle();
    return row?.cast<String, Object?>();
  }

  @override
  Future<Map<String, Object?>> insertSession(
    Map<String, Object?> values,
  ) async {
    final row = await client.from(_sessions).insert(values).select().single();
    return row.cast<String, Object?>();
  }

  @override
  Future<Map<String, Object?>> updateSession(
    String sessionId,
    Map<String, Object?> values,
  ) async {
    final row = await client
        .from(_sessions)
        .update(values)
        .eq('id', sessionId)
        .select()
        .single();
    return row.cast<String, Object?>();
  }

  @override
  Future<List<Map<String, Object?>>> selectSteps(String sessionId) async {
    final rows = await client
        .from(_steps)
        .select()
        .eq('tutorial_v3_session_id', sessionId)
        .order('step_index', ascending: true);
    return rows
        .map((row) => row.cast<String, Object?>())
        .toList(growable: false);
  }

  @override
  Future<int> persistPlan({
    required String sessionId,
    required String? plannerModel,
    required String? plannerPromptVersion,
    required List<Map<String, Object?>> steps,
  }) async {
    final total = await client.rpc(
      'persist_tutorial_v3_plan',
      params: {
        'p_session_id': sessionId,
        'p_planner_model': plannerModel,
        'p_planner_prompt_version': plannerPromptVersion,
        'p_steps': steps,
      },
    );
    return total is int ? total : int.parse('$total');
  }

  @override
  Future<Map<String, Object?>> claimGeometry({
    required String sessionId,
    required int stepIndex,
    required int maxAttempts,
    required int schemaVersion,
  }) async {
    final outcome = await client.rpc(
      'claim_tutorial_v3_geometry',
      params: {
        'p_session_id': sessionId,
        'p_step_index': stepIndex,
        'p_max_attempts': maxAttempts,
        'p_schema_version': schemaVersion,
      },
    );
    if (outcome is Map) return outcome.cast<String, Object?>();
    return <String, Object?>{'outcome': 'unknown'};
  }

  @override
  Future<Map<String, Object?>?> updateStep({
    required String sessionId,
    required int stepIndex,
    required Map<String, Object?> values,
    List<String>? expectedStatuses,
  }) async {
    var query = client
        .from(_steps)
        .update(values)
        .eq('tutorial_v3_session_id', sessionId)
        .eq('step_index', stepIndex);
    if (expectedStatuses != null) {
      query = query.inFilter('geometry_status', expectedStatuses);
    }
    final row = await query.select().maybeSingle();
    return row?.cast<String, Object?>();
  }

  @override
  Future<String?> findOriginalImagePath(String analysisId) async {
    final row = await client
        .from('analyses')
        .select('original_image_path')
        .eq('id', analysisId)
        .maybeSingle();
    final path = row?['original_image_path'];
    return path is String ? path : null;
  }

  @override
  Future<String> createSignedUrl(String storagePath) => client.storage
      .from(TutorialV3StoragePaths.bucket)
      .createSignedUrl(storagePath, 3600);
}
