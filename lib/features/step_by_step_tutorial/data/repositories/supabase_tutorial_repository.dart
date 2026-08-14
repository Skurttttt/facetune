import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/tutorial_generation_status.dart';
import '../../domain/entities/tutorial_instruction.dart';
import '../../domain/entities/tutorial_placement_metadata.dart';
import '../../domain/entities/tutorial_session.dart';
import '../../domain/entities/tutorial_source_mode.dart';
import '../../domain/entities/tutorial_step.dart';
import '../../domain/errors/tutorial_failure.dart';
import '../../domain/repositories/tutorial_repository.dart';
import '../data_sources/tutorial_remote_data_source.dart';
import '../models/tutorial_session_dto.dart';
import '../models/tutorial_step_dto.dart';

class SupabaseTutorialRepository implements TutorialRepository {
  const SupabaseTutorialRepository(this._remote);

  final TutorialRemoteDataSource _remote;

  @override
  Future<TutorialSession?> loadExisting({
    required TutorialSourceMode sourceMode,
    required String analysisId,
    String? recommendationId,
    String? kitRecommendationId,
    required int generationNumber,
  }) async {
    try {
      final row = await _remote.findSession(
        sourceModeCode: sourceMode.code,
        analysisId: analysisId,
        recommendationId: recommendationId,
        kitRecommendationId: kitRecommendationId,
        generationNumber: generationNumber,
      );
      if (row == null) return null;
      final id = row['id'];
      if (id is! String) {
        throw const FormatException('Missing tutorial session id.');
      }
      return TutorialSessionDto.fromRow(row, steps: await loadSteps(id));
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<TutorialSession> createSession({
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
  }) async {
    final userId = _ownerId();
    try {
      final row = await _remote.insertSession(
        TutorialSessionDto.toInsertRow(
          userId: userId,
          sourceMode: sourceMode,
          analysisId: analysisId,
          recommendationId: recommendationId,
          kitRecommendationId: kitRecommendationId,
          styleCode: styleCode,
          generationNumber: generationNumber,
          totalSteps: totalSteps,
          tutorialModel: tutorialModel,
          tutorialImageSize: tutorialImageSize,
          promptVersion: promptVersion,
        ),
      );
      return TutorialSessionDto.fromRow(row, steps: const []);
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<List<TutorialStep>> loadSteps(String tutorialSessionId) async {
    try {
      final rows = await _remote.selectSteps(tutorialSessionId);
      final steps = <TutorialStep>[];
      for (final row in rows) {
        steps.add(await _hydrateStep(TutorialStepDto.fromRow(row)));
      }
      return List.unmodifiable(steps);
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<TutorialStep> createStep({
    required String tutorialSessionId,
    required int stepNumber,
    required String title,
    required TutorialInstruction instruction,
    TutorialPlacementMetadata? placementMetadata,
  }) async {
    final userId = _ownerId();
    try {
      final row = await _remote.insertStep(
        TutorialStepDto.toInsertRow(
          userId: userId,
          tutorialSessionId: tutorialSessionId,
          stepNumber: stepNumber,
          title: title,
          instruction: instruction,
          placementMetadata: placementMetadata,
        ),
      );
      return _hydrateStep(TutorialStepDto.fromRow(row));
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<TutorialStep> updateStepImages({
    required String tutorialStepId,
    String? placementImagePath,
    String? resultImagePath,
    String? modelId,
    int? imageSize,
    String? promptVersion,
  }) async {
    try {
      final row = await _remote.updateStep(
        tutorialStepId,
        TutorialStepDto.imagesUpdateRow(
          placementImagePath: placementImagePath,
          resultImagePath: resultImagePath,
          modelId: modelId,
          imageSize: imageSize,
          promptVersion: promptVersion,
        ),
      );
      return _hydrateStep(TutorialStepDto.fromRow(row));
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<TutorialSession> updateSessionStatus({
    required String tutorialSessionId,
    required TutorialGenerationStatus status,
  }) async {
    try {
      final row = await _remote.updateSession(
        tutorialSessionId,
        TutorialSessionDto.statusUpdateRow(status),
      );
      return TutorialSessionDto.fromRow(
        row,
        steps: await loadSteps(tutorialSessionId),
      );
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<TutorialStep> updateStepStatus({
    required String tutorialStepId,
    required TutorialStepGenerationStatus status,
  }) async {
    try {
      final row = await _remote.updateStep(
        tutorialStepId,
        TutorialStepDto.statusUpdateRow(status),
      );
      return _hydrateStep(TutorialStepDto.fromRow(row));
    } catch (error) {
      throw _failure(error);
    }
  }

  /// Never accept a caller-supplied user id — the owner of every write is
  /// always the authenticated session, matching every other repository in
  /// this codebase (e.g. `SupabaseSavedLooksRepository.save`). Row Level
  /// Security enforces the same rule again, server-side, regardless.
  String _ownerId() {
    final userId = _remote.currentUserId;
    if (userId == null) {
      throw const TutorialFailure(
        TutorialFailureType.authentication,
        'Sign in before starting a tutorial.',
      );
    }
    return userId;
  }

  Future<TutorialStep> _hydrateStep(TutorialStepDto dto) async {
    final placementPath = dto.placementImagePath;
    final resultPath = dto.resultImagePath;
    final urls = await Future.wait([
      placementPath == null
          ? Future<String?>.value()
          : _remote.createSignedUrl(placementPath),
      resultPath == null
          ? Future<String?>.value()
          : _remote.createSignedUrl(resultPath),
    ]);
    return dto.toDomain(placementImageUrl: urls[0], resultImageUrl: urls[1]);
  }

  static TutorialFailure _failure(Object error) {
    if (error is TutorialFailure) return error;
    if (error is SocketException || error is TimeoutException) {
      return const TutorialFailure(
        TutorialFailureType.network,
        'Check your connection and try again.',
        retryable: true,
      );
    }
    if (error is AuthException) {
      return const TutorialFailure(
        TutorialFailureType.authentication,
        'Your session expired. Sign in again.',
      );
    }
    if (error is PostgrestException && _isExpiredSession(error)) {
      return const TutorialFailure(
        TutorialFailureType.authentication,
        'Your session expired. Sign in again.',
      );
    }
    if (error is PostgrestException && error.code == 'PGRST116') {
      return const TutorialFailure(
        TutorialFailureType.notFound,
        'This tutorial could not be found.',
      );
    }
    if (error is PostgrestException || error is StorageException) {
      return const TutorialFailure(
        TutorialFailureType.server,
        'Your tutorial could not be updated right now.',
        retryable: true,
      );
    }
    if (error is FormatException) {
      return const TutorialFailure(
        TutorialFailureType.server,
        'Tutorial data is incomplete.',
        technicalCode: 'malformed_tutorial_data',
      );
    }
    return const TutorialFailure(
      TutorialFailureType.server,
      'Your tutorial could not be loaded.',
      retryable: true,
    );
  }

  static bool _isExpiredSession(PostgrestException error) {
    final detail = '${error.code} ${error.message} ${error.details}'
        .toLowerCase();
    return error.code == 'PGRST301' ||
        (detail.contains('jwt') &&
            (detail.contains('expired') || detail.contains('invalid')));
  }
}
