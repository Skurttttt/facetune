import 'package:facetune/features/analysis/data/data_sources/analysis_remote_data_source.dart';
import 'package:facetune/features/analysis/data/repositories/supabase_face_analysis_repository.dart';
import 'package:facetune/features/analysis/domain/errors/analysis_failure.dart';
import 'package:facetune/features/analysis/domain/repositories/face_analysis_repository.dart';
import 'package:facetune/features/scan/domain/entities/local_image_validation.dart';
import 'package:facetune/features/scan/domain/entities/prepared_selfie.dart';
import 'package:facetune/features/scan/domain/entities/selfie_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final remote = _FakeRemoteDataSource(
      invokeDelay: const Duration(milliseconds: 30),
    );
    final repository = SupabaseFaceAnalysisRepository(
      remote,
      functionTimeout: const Duration(milliseconds: 1),
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
    await Future<void>.delayed(const Duration(milliseconds: 35));
    expect(remote.invokeCount, 1);
  });

  test('bounds selfie upload before invoking secure analysis', () async {
    final remote = _FakeRemoteDataSource(
      uploadDelay: const Duration(milliseconds: 30),
    );
    final repository = SupabaseFaceAnalysisRepository(
      remote,
      uploadTimeout: const Duration(milliseconds: 1),
    );

    await expectLater(
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
              AnalysisFailureType.timeout,
            )
            .having((failure) => failure.retryable, 'retryable', isTrue),
      ),
    );
    expect(remote.invokeCount, 0);
  });

  test('does not expose raw backend messages', () async {
    final repository = SupabaseFaceAnalysisRepository(
      _FakeRemoteDataSource(
        failure: const AnalysisRemoteFailure(
          status: 500,
          code: 'persistence_failed',
          message: 'database_password=do-not-expose',
          retryable: true,
        ),
      ),
    );

    await expectLater(
      () => repository.analyze(
        selfie: selfie,
        localValidation: localValidation,
        onProgress: (_) {},
      ),
      throwsA(
        isA<AnalysisFailure>()
            .having(
              (failure) => failure.message,
              'message',
              'Your analysis could not be saved. Please try again.',
            )
            .having(
              (failure) => failure.message,
              'sanitized message',
              isNot(contains('database_password')),
            ),
      ),
    );
  });

  test('maps status-zero function failures to offline recovery', () async {
    final repository = SupabaseFaceAnalysisRepository(
      _FakeRemoteDataSource(
        failure: const AnalysisRemoteFailure(
          status: 0,
          code: '',
          message: 'raw client exception',
          retryable: false,
        ),
      ),
    );

    await expectLater(
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
              AnalysisFailureType.network,
            )
            .having((failure) => failure.retryable, 'retryable', isTrue),
      ),
    );
  });

  test('recovers from a transient storage upload failure', () async {
    final remote = _FakeRemoteDataSource(
      uploadFailure: const StorageException(
        'bucket policy denied for service_key=do-not-expose',
        statusCode: '500',
      ),
    );
    final repository = SupabaseFaceAnalysisRepository(remote);

    await expectLater(
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
              AnalysisFailureType.server,
            )
            .having((failure) => failure.retryable, 'retryable', isTrue)
            .having(
              (failure) => failure.message,
              'sanitized message',
              isNot(contains('service_key')),
            ),
      ),
    );
    expect(remote.invokeCount, 0);
  });

  test('maps an unauthorized storage upload to session recovery', () async {
    final remote = _FakeRemoteDataSource(
      uploadFailure: const StorageException('denied', statusCode: '403'),
    );
    final repository = SupabaseFaceAnalysisRepository(remote);

    await expectLater(
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
              AnalysisFailureType.authentication,
            )
            .having((failure) => failure.retryable, 'retryable', isFalse),
      ),
    );
    expect(remote.invokeCount, 0);
  });
}

class _FakeRemoteDataSource implements AnalysisRemoteDataSource {
  _FakeRemoteDataSource({
    this.userId = 'authenticated-user',
    this.response,
    this.failure,
    this.invokeDelay = Duration.zero,
    this.uploadDelay = Duration.zero,
    this.uploadFailure,
  });

  final String? userId;
  final Object? response;
  final AnalysisRemoteFailure? failure;
  final Duration invokeDelay;
  final Duration uploadDelay;
  final Object? uploadFailure;
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
    if (uploadDelay > Duration.zero) await Future<void>.delayed(uploadDelay);
    final currentFailure = uploadFailure;
    if (currentFailure != null) throw currentFailure;
  }
}
