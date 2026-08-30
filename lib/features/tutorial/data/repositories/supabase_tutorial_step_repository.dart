import 'dart:async';

import '../../domain/entities/look_product_snapshot.dart';
import '../../domain/entities/tutorial_category.dart';
import '../../domain/entities/tutorial_step.dart';
import '../../domain/errors/tutorial_failure.dart';
import '../../domain/repositories/tutorial_step_repository.dart';
import '../data_sources/tutorial_remote_data_source.dart';
import '../models/tutorial_dtos.dart';
import 'supabase_tutorial_repositories.dart';

/// Generates and retrieves rendered guideline steps.
///
/// One category per call. There is deliberately no batch method: a batch would
/// make "generate everything on open" a single easy mistake, and the whole cost
/// model depends on that being impossible to express.
class SupabaseTutorialStepRepository
    with TutorialErrorMapping
    implements TutorialStepRepository {
  SupabaseTutorialStepRepository(
    this.remote, {
    Duration readTimeout = const Duration(seconds: 20),
    Duration generateTimeout = const Duration(seconds: 150),
  }) : _readTimeout = readTimeout,
       _generateTimeout = generateTimeout;

  @override
  final TutorialRemoteDataSource remote;
  final Duration _readTimeout;
  final Duration _generateTimeout;

  @override
  Future<List<TutorialStep>> loadForSession(String sessionId) async {
    requireAuthentication();
    try {
      final rows = await remote.fetchSteps(sessionId).timeout(_readTimeout);
      return <TutorialStep>[
        for (final row in rows)
          TutorialStepDto.fromRow(
            row,
            snapshot: LookProductSnapshot.empty,
            isMyMakeupKit: false,
          ),
      ];
    } catch (error) {
      throw map(error);
    }
  }

  @override
  Future<TutorialStep> generate({
    required String sessionId,
    required TutorialCategory category,
  }) async {
    requireAuthentication();
    try {
      await remote
          .generateStep(tutorialSessionId: sessionId, category: category.code)
          .timeout(_generateTimeout);
      // Re-read rather than trust the response body. The persisted row is what
      // every later reopen reads, so proving it landed is worth one query — and
      // it keeps the reused and freshly-generated paths identical here.
      final rows = await remote.fetchSteps(sessionId).timeout(_readTimeout);
      for (final row in rows) {
        final step = TutorialStepDto.fromRow(
          row,
          snapshot: LookProductSnapshot.empty,
          isMyMakeupKit: false,
        );
        if (step.category == category) return step;
      }
      throw const TutorialFailure(
        'This tutorial step could not be prepared.',
        kind: TutorialFailureKind.stepGenerationFailed,
      );
    } catch (error) {
      throw map(error);
    }
  }

  @override
  Future<String> resolveGuidelineUrl(TutorialStep step) async {
    requireAuthentication();
    final path = step.guidelineStoragePath;
    if (path == null) {
      throw const TutorialFailure(
        'This tutorial step is not ready yet.',
        kind: TutorialFailureKind.validation,
        retryable: false,
      );
    }
    try {
      return await remote.createSignedUrl(path).timeout(_readTimeout);
    } catch (error) {
      throw map(error);
    }
  }
}
