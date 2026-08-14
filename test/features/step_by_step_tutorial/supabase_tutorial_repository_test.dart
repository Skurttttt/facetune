import 'package:facetune/features/step_by_step_tutorial/data/data_sources/tutorial_remote_data_source.dart';
import 'package:facetune/features/step_by_step_tutorial/data/repositories/supabase_tutorial_repository.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_generation_status.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_source_mode.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step_category.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/errors/tutorial_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('createSession', () {
    test('maps a unique-violation (23505) to a recognizable duplicate_session '
        'failure, not a generic server error', () async {
      final repository = SupabaseTutorialRepository(
        _ThrowingRemoteDataSource(
          PostgrestException(message: 'duplicate key value', code: '23505'),
        ),
      );

      await expectLater(
        repository.createSession(
          sourceMode: TutorialSourceMode.standardRecommendation,
          analysisId: 'analysis-1',
          recommendationId: 'recommendation-1',
          styleCode: 'soft_glam',
          generationNumber: 1,
          totalSteps: 3,
        ),
        throwsA(
          isA<TutorialFailure>()
              .having(
                (failure) => failure.technicalCode,
                'technicalCode',
                'duplicate_session',
              )
              .having((failure) => failure.retryable, 'retryable', isFalse),
        ),
      );
    });

    test(
      'maps a foreign-key violation (23503) to a non-retryable '
      '"source deleted" failure, not a generic retryable server error',
      () async {
        final repository = SupabaseTutorialRepository(
          _ThrowingRemoteDataSource(
            PostgrestException(
              message: 'violates foreign key constraint',
              code: '23503',
            ),
          ),
        );

        await expectLater(
          repository.createSession(
            sourceMode: TutorialSourceMode.standardRecommendation,
            analysisId: 'analysis-1',
            recommendationId: 'recommendation-1',
            styleCode: 'soft_glam',
            generationNumber: 1,
            totalSteps: 3,
          ),
          throwsA(
            isA<TutorialFailure>()
                .having(
                  (failure) => failure.type,
                  'type',
                  TutorialFailureType.notFound,
                )
                .having(
                  (failure) => failure.technicalCode,
                  'technicalCode',
                  'source_deleted',
                )
                .having((failure) => failure.retryable, 'retryable', isFalse),
          ),
        );
      },
    );

    test(
      'maps an unrelated Postgrest error to the generic server failure',
      () async {
        final repository = SupabaseTutorialRepository(
          _ThrowingRemoteDataSource(
            PostgrestException(message: 'connection reset', code: '08006'),
          ),
        );

        await expectLater(
          repository.createSession(
            sourceMode: TutorialSourceMode.standardRecommendation,
            analysisId: 'analysis-1',
            recommendationId: 'recommendation-1',
            styleCode: 'soft_glam',
            generationNumber: 1,
            totalSteps: 3,
          ),
          throwsA(
            isA<TutorialFailure>()
                .having(
                  (failure) => failure.technicalCode,
                  'technicalCode',
                  isNot('duplicate_session'),
                )
                .having((failure) => failure.retryable, 'retryable', isTrue),
          ),
        );
      },
    );
  });

  group('generateStepResult', () {
    Map<String, Object?> stepRow() => {
      'id': 'step-2',
      'tutorial_session_id': 'session-1',
      'step_number': 2,
      'category': 'blush',
      'title': 'Blush',
      'instruction_json': {
        'placement': 'Upper cheekbones',
        'intensity': 'light',
        'technique': 'Blend upward.',
      },
      'placement_metadata_json': const [],
      'placement_image_path': 'user-1/analyses/a1/tutorials/s1/step_0001.png',
      'result_image_path': 'user-1/analyses/a1/tutorials/s1/step_0002.png',
      'model_name': 'gemini-3.1-flash-image',
      'image_size': 512,
      'prompt_version': 'tutorial_step_v1',
      'generation_status': 'completed',
      'created_at': '2026-08-14T00:00:00Z',
      'updated_at': '2026-08-14T00:00:00Z',
    };

    test('parses the {step: ...} envelope and hydrates signed URLs', () async {
      final repository = SupabaseTutorialRepository(
        _InvokingRemoteDataSource(response: {'step': stepRow()}),
      );

      final step = await repository.generateStepResult(
        tutorialStepId: 'step-2',
      );

      expect(step.id, 'step-2');
      expect(step.resultImageUrl, 'https://signed.example/url');
      expect(step.placementImageUrl, 'https://signed.example/url');
    });

    test('maps a PREVIOUS_STEP_NOT_READY failure to validation', () async {
      final repository = SupabaseTutorialRepository(
        _InvokingRemoteDataSource(
          error: const TutorialRemoteFailure(
            status: 409,
            code: 'PREVIOUS_STEP_NOT_READY',
            message: 'Generate the previous tutorial step before this one.',
            retryable: false,
          ),
        ),
      );

      await expectLater(
        repository.generateStepResult(tutorialStepId: 'step-2'),
        throwsA(
          isA<TutorialFailure>().having(
            (failure) => failure.type,
            'type',
            TutorialFailureType.validation,
          ),
        ),
      );
    });

    test('maps an AUTH_FAILED failure to authentication', () async {
      final repository = SupabaseTutorialRepository(
        _InvokingRemoteDataSource(
          error: const TutorialRemoteFailure(
            status: 401,
            code: 'AUTH_FAILED',
            message: 'Your session has expired. Sign in again.',
            retryable: false,
          ),
        ),
      );

      await expectLater(
        repository.generateStepResult(tutorialStepId: 'step-2'),
        throwsA(
          isA<TutorialFailure>().having(
            (failure) => failure.type,
            'type',
            TutorialFailureType.authentication,
          ),
        ),
      );
    });

    test('maps a TUTORIAL_STEP_NOT_FOUND failure to notFound', () async {
      final repository = SupabaseTutorialRepository(
        _InvokingRemoteDataSource(
          error: const TutorialRemoteFailure(
            status: 404,
            code: 'TUTORIAL_STEP_NOT_FOUND',
            message: 'This tutorial step could not be found.',
            retryable: false,
          ),
        ),
      );

      await expectLater(
        repository.generateStepResult(tutorialStepId: 'step-2'),
        throwsA(
          isA<TutorialFailure>().having(
            (failure) => failure.type,
            'type',
            TutorialFailureType.notFound,
          ),
        ),
      );
    });

    test('maps a GEMINI_ prefixed failure to gemini', () async {
      final repository = SupabaseTutorialRepository(
        _InvokingRemoteDataSource(
          error: const TutorialRemoteFailure(
            status: 502,
            code: 'GEMINI_NO_IMAGE_OUTPUT',
            message: 'The image service did not return a usable image.',
            retryable: true,
          ),
        ),
      );

      await expectLater(
        repository.generateStepResult(tutorialStepId: 'step-2'),
        throwsA(
          isA<TutorialFailure>()
              .having(
                (failure) => failure.type,
                'type',
                TutorialFailureType.gemini,
              )
              .having((failure) => failure.retryable, 'retryable', isTrue),
        ),
      );
    });

    test('maps an unrecognized failure code to server', () async {
      final repository = SupabaseTutorialRepository(
        _InvokingRemoteDataSource(
          error: const TutorialRemoteFailure(
            status: 500,
            code: 'STORAGE_UPLOAD_FAILED',
            message: 'The generated tutorial step image could not be stored.',
            retryable: true,
          ),
        ),
      );

      await expectLater(
        repository.generateStepResult(tutorialStepId: 'step-2'),
        throwsA(
          isA<TutorialFailure>().having(
            (failure) => failure.type,
            'type',
            TutorialFailureType.server,
          ),
        ),
      );
    });
  });

  group('resetForRegeneration', () {
    test('excludes the final_look category and returns not_started, '
        're-loaded with fresh steps', () async {
      final remote = _ResettingRemoteDataSource(
        stepsAfterReset: [
          {
            'id': 'step-1',
            'tutorial_session_id': 'session-1',
            'step_number': 1,
            'category': 'blush',
            'title': 'Blush',
            'instruction_json': {
              'placement': 'Upper cheekbones',
              'intensity': 'light',
              'technique': 'Blend upward.',
            },
            'placement_metadata_json': const [],
            'placement_image_path': null,
            'result_image_path': null,
            'model_name': null,
            'image_size': null,
            'prompt_version': null,
            'generation_status': 'not_started',
            'created_at': '2026-08-14T00:00:00Z',
            'updated_at': '2026-08-14T00:00:00Z',
          },
        ],
      );
      final repository = SupabaseTutorialRepository(remote);

      final session = await repository.resetForRegeneration(
        tutorialSessionId: 'session-1',
      );

      expect(remote.resetCalls, 1);
      expect(
        remote.lastExcludedCategoryCode,
        TutorialStepCategory.finalLook.code,
      );
      expect(
        remote.lastResetValues,
        containsPair('generation_status', 'not_started'),
      );
      expect(remote.lastResetValues, containsPair('result_image_path', isNull));
      expect(session.generationStatus, TutorialGenerationStatus.notStarted);
      expect(session.steps.single.resultImageUrl, isNull);
    });

    test('surfaces a reset failure as a normal TutorialFailure', () async {
      final remote = _ResettingRemoteDataSource(
        resetError: const TutorialRemoteFailure(
          status: 500,
          code: 'server_error',
          message: 'Could not reset.',
          retryable: true,
        ),
      );
      final repository = SupabaseTutorialRepository(remote);

      await expectLater(
        repository.resetForRegeneration(tutorialSessionId: 'session-1'),
        throwsA(isA<TutorialFailure>()),
      );
    });
  });
}

class _ThrowingRemoteDataSource implements TutorialRemoteDataSource {
  _ThrowingRemoteDataSource(this._error);

  final Object _error;

  @override
  String? get currentUserId => 'user-1';

  @override
  Future<Object?> invoke({required String tutorialStepId}) =>
      throw UnimplementedError();

  @override
  Future<Map<String, Object?>> insertSession(Map<String, Object?> values) =>
      throw _error;

  @override
  Future<Map<String, Object?>?> findSession({
    required String sourceModeCode,
    required String analysisId,
    String? recommendationId,
    String? kitRecommendationId,
    required int generationNumber,
  }) => throw UnimplementedError();

  @override
  Future<Map<String, Object?>> updateSession(
    String sessionId,
    Map<String, Object?> values,
  ) => throw UnimplementedError();

  @override
  Future<List<Map<String, Object?>>> selectSteps(String tutorialSessionId) =>
      throw UnimplementedError();

  @override
  Future<Map<String, Object?>> insertStep(Map<String, Object?> values) =>
      throw UnimplementedError();

  @override
  Future<Map<String, Object?>> updateStep(
    String stepId,
    Map<String, Object?> values,
  ) => throw UnimplementedError();

  @override
  Future<void> resetSteps({
    required String tutorialSessionId,
    required Map<String, Object?> values,
    required String excludedCategoryCode,
  }) => throw UnimplementedError();

  @override
  Future<String> createSignedUrl(String storagePath) =>
      throw UnimplementedError();
}

/// Backs the [SupabaseTutorialRepository.generateStepResult] tests:
/// [invoke] either resolves with [response] or throws [error], and
/// [createSignedUrl] always resolves so the success case can verify
/// hydration happened.
class _InvokingRemoteDataSource implements TutorialRemoteDataSource {
  _InvokingRemoteDataSource({this.response, this.error});

  final Map<String, Object?>? response;
  final TutorialRemoteFailure? error;

  @override
  String? get currentUserId => 'user-1';

  @override
  Future<Object?> invoke({required String tutorialStepId}) async {
    if (error != null) throw error!;
    return response;
  }

  @override
  Future<String> createSignedUrl(String storagePath) async =>
      'https://signed.example/url';

  @override
  Future<Map<String, Object?>> insertSession(Map<String, Object?> values) =>
      throw UnimplementedError();

  @override
  Future<Map<String, Object?>?> findSession({
    required String sourceModeCode,
    required String analysisId,
    String? recommendationId,
    String? kitRecommendationId,
    required int generationNumber,
  }) => throw UnimplementedError();

  @override
  Future<Map<String, Object?>> updateSession(
    String sessionId,
    Map<String, Object?> values,
  ) => throw UnimplementedError();

  @override
  Future<List<Map<String, Object?>>> selectSteps(String tutorialSessionId) =>
      throw UnimplementedError();

  @override
  Future<Map<String, Object?>> insertStep(Map<String, Object?> values) =>
      throw UnimplementedError();

  @override
  Future<Map<String, Object?>> updateStep(
    String stepId,
    Map<String, Object?> values,
  ) => throw UnimplementedError();

  @override
  Future<void> resetSteps({
    required String tutorialSessionId,
    required Map<String, Object?> values,
    required String excludedCategoryCode,
  }) => throw UnimplementedError();
}

/// Backs the [SupabaseTutorialRepository.resetForRegeneration] tests:
/// [resetSteps] records what it was called with (and either succeeds or
/// throws [resetError]), [updateSession] echoes back a valid, otherwise
/// static session row, and [selectSteps] returns [stepsAfterReset] — the
/// repository's own [SupabaseTutorialRepository.loadSteps] re-fetch after
/// resetting, so a test can assert what the caller ultimately sees.
class _ResettingRemoteDataSource implements TutorialRemoteDataSource {
  _ResettingRemoteDataSource({
    this.resetError,
    this.stepsAfterReset = const [],
  });

  final TutorialRemoteFailure? resetError;
  final List<Map<String, Object?>> stepsAfterReset;

  int resetCalls = 0;
  Map<String, Object?>? lastResetValues;
  String? lastExcludedCategoryCode;

  @override
  String? get currentUserId => 'user-1';

  @override
  Future<void> resetSteps({
    required String tutorialSessionId,
    required Map<String, Object?> values,
    required String excludedCategoryCode,
  }) async {
    resetCalls++;
    lastResetValues = values;
    lastExcludedCategoryCode = excludedCategoryCode;
    if (resetError != null) throw resetError!;
  }

  @override
  Future<Map<String, Object?>> updateSession(
    String sessionId,
    Map<String, Object?> values,
  ) async => {
    'id': sessionId,
    'user_id': 'user-1',
    'source_mode': 'standard_recommendation',
    'analysis_id': 'analysis-1',
    'recommendation_id': 'recommendation-1',
    'kit_recommendation_id': null,
    'makeup_style': 'soft_glam',
    'generation_number': 1,
    'total_steps': 1,
    'generation_status': values['generation_status'],
    'prompt_version': null,
    'tutorial_model': null,
    'tutorial_image_size': null,
    'created_at': '2026-08-14T00:00:00Z',
    'updated_at': '2026-08-14T00:00:00Z',
  };

  @override
  Future<List<Map<String, Object?>>> selectSteps(
    String tutorialSessionId,
  ) async => stepsAfterReset;

  @override
  Future<Object?> invoke({required String tutorialStepId}) =>
      throw UnimplementedError();

  @override
  Future<Map<String, Object?>?> findSession({
    required String sourceModeCode,
    required String analysisId,
    String? recommendationId,
    String? kitRecommendationId,
    required int generationNumber,
  }) => throw UnimplementedError();

  @override
  Future<Map<String, Object?>> insertSession(Map<String, Object?> values) =>
      throw UnimplementedError();

  @override
  Future<Map<String, Object?>> insertStep(Map<String, Object?> values) =>
      throw UnimplementedError();

  @override
  Future<Map<String, Object?>> updateStep(
    String stepId,
    Map<String, Object?> values,
  ) => throw UnimplementedError();

  @override
  Future<String> createSignedUrl(String storagePath) async =>
      'https://signed.example/url';
}
