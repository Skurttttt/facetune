import 'package:facetune/features/analysis/data/data_sources/analysis_remote_data_source.dart';
import 'package:facetune/features/analysis/data/repositories/supabase_face_analysis_repository.dart';
import 'package:facetune/features/analysis/domain/errors/analysis_failure.dart';
import 'package:facetune/features/analysis/domain/repositories/face_analysis_repository.dart';
import 'package:facetune/features/scan/domain/entities/local_image_validation.dart';
import 'package:facetune/features/scan/domain/entities/prepared_selfie.dart';
import 'package:facetune/features/scan/domain/entities/selfie_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/analysis_response_fixture.dart';

void main() {
  const selfie = PreparedSelfie(
    originalPath: 'original.jpg',
    uploadPath: 'upload.jpg',
    originalSizeBytes: 1000,
    uploadSizeBytes: 700,
    source: SelfieSource.gallery,
  );
  const localValidation = LocalImageValidation(
    mimeType: 'image/jpeg',
    width: 1080,
    height: 1440,
    originalSizeBytes: 1000,
    uploadSizeBytes: 700,
  );

  test('requires an authenticated session before upload', () async {
    final repository = SupabaseFaceAnalysisRepository(
      _FakeRemoteDataSource(userId: null),
    );

    expect(
      () => repository.analyze(
        selfie: selfie,
        localValidation: localValidation,
        onProgress: (_) {},
      ),
      throwsA(
        isA<AnalysisFailure>().having(
          (failure) => failure.type,
          'type',
          AnalysisFailureType.authentication,
        ),
      ),
    );
  });

  test('uploads, invokes, and returns the persisted typed result', () async {
    final remote = _FakeRemoteDataSource(response: validAnalysisResponse);
    final progress = <AnalysisProgress>[];
    final repository = SupabaseFaceAnalysisRepository(remote);

    final result = await repository.analyze(
      selfie: selfie,
      localValidation: localValidation,
      onProgress: progress.add,
    );

    expect(result.id, '8ad50d8d-ff1c-4b1f-a376-58642328f463');
    expect(remote.uploadCount, 1);
    expect(remote.invokeCount, 1);
    expect(progress, [
      AnalysisProgress.uploading,
      AnalysisProgress.secureProcessing,
    ]);
  });

  test('maps deterministic Edge Function validation errors', () async {
    final repository = SupabaseFaceAnalysisRepository(
      _FakeRemoteDataSource(
        failure: const AnalysisRemoteFailure(
          status: 422,
          code: 'no_face',
          message: 'No visible face was found.',
          retryable: false,
        ),
      ),
    );

    expect(
      () => repository.analyze(
        selfie: selfie,
        localValidation: localValidation,
        onProgress: (_) {},
      ),
      throwsA(
        isA<AnalysisFailure>()
            .having(
              (failure) => failure.type,
              'type',
              AnalysisFailureType.validation,
            )
            .having((failure) => failure.retryable, 'retryable', false),
      ),
    );
  });

  test('bounds a timed-out function request', () async {
    final repository = SupabaseFaceAnalysisRepository(
      _FakeRemoteDataSource(invokeDelay: const Duration(milliseconds: 30)),
      functionTimeout: const Duration(milliseconds: 1),
      maximumAttempts: 1,
    );

    expect(
      () => repository.analyze(
        selfie: selfie,
        localValidation: localValidation,
        onProgress: (_) {},
      ),
      throwsA(
        isA<AnalysisFailure>().having(
          (failure) => failure.type,
          'type',
          AnalysisFailureType.timeout,
        ),
      ),
    );
  });
}

class _FakeRemoteDataSource implements AnalysisRemoteDataSource {
  _FakeRemoteDataSource({
    this.userId = 'authenticated-user',
    this.response,
    this.failure,
    this.invokeDelay = Duration.zero,
  });

  final String? userId;
  final Object? response;
  final AnalysisRemoteFailure? failure;
  final Duration invokeDelay;
  int uploadCount = 0;
  int invokeCount = 0;

  @override
  String? get currentUserId => userId;

  @override
  Future<Object?> invokeAnalysis({
    required String analysisId,
    required String storagePath,
    required LocalImageValidation localValidation,
  }) async {
    invokeCount += 1;
    if (invokeDelay > Duration.zero) await Future<void>.delayed(invokeDelay);
    final currentFailure = failure;
    if (currentFailure != null) throw currentFailure;
    return response;
  }

  @override
  Future<void> uploadSelfie({
    required String localPath,
    required String storagePath,
  }) async {
    uploadCount += 1;
  }
}
