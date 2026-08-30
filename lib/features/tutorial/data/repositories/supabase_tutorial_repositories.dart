import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/catalog/tutorial_step_planner.dart';
import '../../domain/entities/canonical_preview_ref.dart';
import '../../domain/entities/recommendation_source_mode.dart';
import '../../domain/entities/tutorial_session.dart';
import '../../domain/entities/tutorial_step.dart';
import '../../domain/entities/validated_look_plan.dart';
import '../../domain/errors/tutorial_failure.dart';
import '../../domain/repositories/look_plan_repository.dart';
import '../../domain/repositories/tutorial_manifest_repository.dart';
import '../../domain/repositories/tutorial_session_repository.dart';
import '../data_sources/tutorial_remote_data_source.dart';
import '../models/tutorial_dtos.dart';

/// Shared failure mapping and auth guard.
///
/// Every message here is user-facing and generic; the underlying PostgREST or
/// Function error is never surfaced, so a database structure cannot leak
/// through an error string.
mixin TutorialErrorMapping {
  TutorialRemoteDataSource get remote;

  void requireAuthentication() {
    if (remote.currentUserId == null) {
      throw const TutorialFailure(
        'Sign in to open this tutorial.',
        kind: TutorialFailureKind.sessionExpired,
        retryable: false,
      );
    }
  }

  TutorialFailure map(Object error) {
    if (error is TutorialFailure) return error;
    if (error is TutorialRemoteFailure) {
      return TutorialFailure(
        error.message,
        kind: switch (error.code) {
          'rate_limited' => TutorialFailureKind.quotaExceeded,
          'visual_comparison_unavailable' =>
            TutorialFailureKind.manifestUnavailable,
          'unsupported_inventory_category' =>
            TutorialFailureKind.unsupportedCategory,
          'canonical_preview_not_found' ||
          'source_image_not_found' ||
          'kit_recommendation_not_found' => TutorialFailureKind.notFound,
          'authentication_required' ||
          'invalid_session' => TutorialFailureKind.sessionExpired,
          _ when error.status == 401 => TutorialFailureKind.sessionExpired,
          _ when error.status >= 500 => TutorialFailureKind.unavailable,
          _ => TutorialFailureKind.validation,
        },
        retryable: error.retryable,
      );
    }
    if (error is TimeoutException) {
      return const TutorialFailure(
        'Preparing this tutorial took too long. Check your connection.',
        kind: TutorialFailureKind.timeout,
      );
    }
    if (error is SocketException) {
      return const TutorialFailure(
        'You appear to be offline.',
        kind: TutorialFailureKind.offline,
      );
    }
    if (error is PostgrestException) {
      return TutorialFailure(
        'This tutorial could not be loaded right now.',
        kind: error.code == 'PGRST301' || error.code == '42501'
            ? TutorialFailureKind.sessionExpired
            : TutorialFailureKind.unavailable,
      );
    }
    return const TutorialFailure(
      'This tutorial could not be loaded right now.',
      kind: TutorialFailureKind.unknown,
    );
  }
}

/// Resolves the validated look plan behind a canonical preview.
class SupabaseLookPlanRepository
    with TutorialErrorMapping
    implements LookPlanRepository {
  SupabaseLookPlanRepository(
    this.remote, {
    Duration timeout = const Duration(seconds: 20),
  }) : _timeout = timeout;

  @override
  final TutorialRemoteDataSource remote;
  final Duration _timeout;

  @override
  Future<ValidatedLookPlan> loadForCanonicalPreview(
    CanonicalPreviewRef preview,
  ) async {
    requireAuthentication();
    try {
      final isKit = preview.isMyMakeupKit;
      final previewRow = await remote
          .fetchPreview(previewId: preview.id, isMyMakeupKit: isKit)
          .timeout(_timeout);
      if (previewRow == null) {
        throw const TutorialFailure(
          'This look could not be found.',
          kind: TutorialFailureKind.notFound,
          retryable: false,
        );
      }
      final recommendationId =
          previewRow[isKit ? 'kit_recommendation_id' : 'recommendation_id']
              ?.toString();
      if (recommendationId == null) {
        throw const TutorialFailure(
          'This look could not be found.',
          kind: TutorialFailureKind.notFound,
          retryable: false,
        );
      }
      final row = await remote
          .fetchRecommendation(
            recommendationId: recommendationId,
            isMyMakeupKit: isKit,
          )
          .timeout(_timeout);
      if (row == null) {
        throw const TutorialFailure(
          'The makeup plan for this look is no longer available.',
          kind: TutorialFailureKind.notFound,
          retryable: false,
        );
      }
      return LookPlanDto.fromRow(row, sourceMode: preview.sourceMode);
    } catch (error) {
      throw map(error);
    }
  }
}

/// Loads and analyzes the visual manifest.
class SupabaseTutorialManifestRepository
    with TutorialErrorMapping
    implements TutorialManifestRepository {
  SupabaseTutorialManifestRepository(
    this.remote,
    this._lookPlans, {
    Duration readTimeout = const Duration(seconds: 20),
    Duration analyzeTimeout = const Duration(seconds: 120),
  }) : _readTimeout = readTimeout,
       _analyzeTimeout = analyzeTimeout;

  @override
  final TutorialRemoteDataSource remote;
  final LookPlanRepository _lookPlans;
  final Duration _readTimeout;
  final Duration _analyzeTimeout;

  @override
  Future<TutorialSession?> loadAccepted(CanonicalPreviewRef preview) async {
    requireAuthentication();
    try {
      final session = await _read(preview);
      if (session == null || !session.hasReusableManifest) return null;
      return session;
    } catch (error) {
      throw map(error);
    }
  }

  @override
  Future<TutorialSession> analyze(CanonicalPreviewRef preview) async {
    requireAuthentication();
    try {
      // The server reuses an accepted manifest for this preview, so a call
      // that races another client is wasteful but never double-charged.
      await remote
          .analyzeManifest(
            previewId: preview.id,
            isMyMakeupKit: preview.isMyMakeupKit,
          )
          .timeout(_analyzeTimeout);
      // Re-read rather than trust the response body: the persisted rows are
      // what every later phase reads, so proving they landed is worth one
      // cheap query.
      final session = await _read(preview);
      if (session == null) {
        throw const TutorialFailure(
          'This tutorial could not be prepared.',
          kind: TutorialFailureKind.manifestUnavailable,
        );
      }
      return session;
    } catch (error) {
      throw map(error);
    }
  }

  Future<TutorialSession?> _read(CanonicalPreviewRef preview) async {
    final row = await remote
        .fetchSession(
          previewId: preview.id,
          isMyMakeupKit: preview.isMyMakeupKit,
        )
        .timeout(_readTimeout);
    if (row == null) return null;
    final lookPlan = await _lookPlans.loadForCanonicalPreview(preview);
    return TutorialSessionAssembler.assemble(
      sessionRow: row,
      preview: preview,
      lookPlan: lookPlan,
      manifestItemRows: await remote
          .fetchManifestItems(row['id'].toString())
          .timeout(_readTimeout),
      stepRows: await remote
          .fetchSteps(row['id'].toString())
          .timeout(_readTimeout),
    );
  }
}

/// Creates and materialises tutorial sessions.
class SupabaseTutorialSessionRepository
    with TutorialErrorMapping
    implements TutorialSessionRepository {
  SupabaseTutorialSessionRepository(
    this.remote,
    this._lookPlans, {
    Duration timeout = const Duration(seconds: 20),
  }) : _timeout = timeout;

  @override
  final TutorialRemoteDataSource remote;
  final LookPlanRepository _lookPlans;
  final Duration _timeout;

  @override
  Future<TutorialSession?> loadForCanonicalPreview(
    CanonicalPreviewRef preview,
  ) async {
    requireAuthentication();
    try {
      final row = await remote
          .fetchSession(
            previewId: preview.id,
            isMyMakeupKit: preview.isMyMakeupKit,
          )
          .timeout(_timeout);
      if (row == null) return null;
      return _assemble(row, preview);
    } catch (error) {
      throw map(error);
    }
  }

  @override
  Future<TutorialSession> loadById(String sessionId) async {
    requireAuthentication();
    try {
      final row = await remote.fetchSessionById(sessionId).timeout(_timeout);
      if (row == null) {
        throw const TutorialFailure(
          'This tutorial could not be found.',
          kind: TutorialFailureKind.notFound,
          retryable: false,
        );
      }
      return _assemble(row, _previewRefFrom(row));
    } catch (error) {
      throw map(error);
    }
  }

  @override
  Future<TutorialSession> ensureSteps(TutorialSession session) async {
    requireAuthentication();
    try {
      final planned = TutorialStepPlanner.plan(
        manifest: session.manifest!,
        lookPlan: session.lookPlan,
      );
      final missing = TutorialStepPlanner.missingSteps(
        planned: planned,
        existing: session.steps,
      );
      if (missing.isEmpty) return session;

      await remote
          .insertSteps(<Map<String, Object?>>[
            for (final step in missing)
              <String, Object?>{
                'user_id': session.userId,
                'tutorial_session_id': session.id,
                'category': step.category.code,
                'position': step.position,
                'status': TutorialStepStatus.pending.code,
              },
          ])
          .timeout(_timeout);

      // Re-read so a step another device created concurrently is reflected too,
      // rather than assuming this client's insert is the whole truth.
      final stepRows = await remote.fetchSteps(session.id).timeout(_timeout);
      return TutorialSessionAssembler.withSteps(
        session: session,
        stepRows: stepRows,
      );
    } catch (error) {
      throw map(error);
    }
  }

  @override
  Future<void> delete(String sessionId) async {
    requireAuthentication();
    try {
      await remote.deleteSession(sessionId).timeout(_timeout);
    } catch (error) {
      throw map(error);
    }
  }

  CanonicalPreviewRef _previewRefFrom(Map<String, Object?> row) {
    final kitPreview = row['canonical_kit_generated_image_id']?.toString();
    if (kitPreview != null) {
      return CanonicalPreviewRef.myMakeupKit(kitPreview);
    }
    final standardPreview = row['canonical_generated_image_id']?.toString();
    if (standardPreview != null) {
      return CanonicalPreviewRef.standard(standardPreview);
    }
    throw const TutorialFailure(
      'This tutorial could not be loaded right now.',
      kind: TutorialFailureKind.validation,
      retryable: false,
    );
  }

  Future<TutorialSession> _assemble(
    Map<String, Object?> row,
    CanonicalPreviewRef preview,
  ) async {
    final lookPlan = await _lookPlans.loadForCanonicalPreview(preview);
    return TutorialSessionAssembler.assemble(
      sessionRow: row,
      preview: preview,
      lookPlan: lookPlan,
      manifestItemRows: await remote
          .fetchManifestItems(row['id'].toString())
          .timeout(_timeout),
      stepRows: await remote.fetchSteps(row['id'].toString()).timeout(_timeout),
    );
  }
}

/// Builds a [TutorialSession] from its rows.
///
/// Shared by both repositories so there is one definition of how a session is
/// assembled, and one place where the source-mode agreement is enforced.
abstract final class TutorialSessionAssembler {
  static TutorialSession assemble({
    required Map<String, Object?> sessionRow,
    required CanonicalPreviewRef preview,
    required ValidatedLookPlan lookPlan,
    required List<Object?> manifestItemRows,
    required List<Object?> stepRows,
  }) {
    final storedMode = RecommendationSourceMode.fromCode(
      sessionRow['source_mode']?.toString() ?? '',
    );
    // Source mode cannot change inside an existing canonical session. Three
    // independent sources must agree — the stored row, the preview reference,
    // and the look plan — and a disagreement fails rather than picking one.
    if (storedMode == null ||
        storedMode != preview.sourceMode ||
        storedMode != lookPlan.sourceMode) {
      throw const TutorialFailure(
        'This tutorial could not be loaded right now.',
        kind: TutorialFailureKind.validation,
        retryable: false,
      );
    }
    final status = TutorialSessionStatus.fromCode(
      sessionRow['status']?.toString() ?? '',
    );
    if (status == null) {
      throw const TutorialFailure(
        'This tutorial is in a state this app version does not support.',
        kind: TutorialFailureKind.validation,
        retryable: false,
      );
    }
    final manifest = manifestItemRows.isEmpty
        ? null
        : TutorialManifestDto.fromRows(
            session: sessionRow,
            itemRows: manifestItemRows,
            preview: preview,
          );
    return TutorialSession(
      id: sessionRow['id'].toString(),
      userId: sessionRow['user_id'].toString(),
      analysisId: sessionRow['analysis_id'].toString(),
      canonicalPreviewId: preview.id,
      lookPlan: lookPlan,
      status: status,
      manifest: manifest,
      steps: _steps(stepRows, lookPlan, preview),
      createdAt:
          DateTime.tryParse(sessionRow['created_at']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      updatedAt:
          DateTime.tryParse(sessionRow['updated_at']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      completedAt: DateTime.tryParse(
        sessionRow['completed_at']?.toString() ?? '',
      ),
    );
  }

  /// Returns [session] with freshly read step rows, leaving everything else
  /// untouched.
  static TutorialSession withSteps({
    required TutorialSession session,
    required List<Object?> stepRows,
  }) => TutorialSession(
    id: session.id,
    userId: session.userId,
    analysisId: session.analysisId,
    canonicalPreviewId: session.canonicalPreviewId,
    lookPlan: session.lookPlan,
    status: session.status,
    manifest: session.manifest,
    steps: _steps(
      stepRows,
      session.lookPlan,
      CanonicalPreviewRef(
        id: session.canonicalPreviewId,
        sourceMode: session.sourceMode,
      ),
    ),
    aiConfiguration: session.aiConfiguration,
    createdAt: session.createdAt,
    updatedAt: session.updatedAt,
    completedAt: session.completedAt,
  );

  static List<TutorialStep> _steps(
    List<Object?> rows,
    ValidatedLookPlan lookPlan,
    CanonicalPreviewRef preview,
  ) => <TutorialStep>[
    for (final row in rows)
      TutorialStepDto.fromRow(
        row,
        snapshot: lookPlan.productSnapshot,
        isMyMakeupKit: preview.isMyMakeupKit,
      ),
  ];
}
