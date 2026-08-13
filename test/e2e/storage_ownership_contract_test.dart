import 'package:facetune/features/analysis/data/data_sources/analysis_remote_data_source.dart';
import 'package:facetune/features/analysis/data/repositories/supabase_face_analysis_repository.dart';
import 'package:facetune/features/scan/domain/entities/local_image_validation.dart';
import 'package:facetune/features/scan/domain/entities/prepared_selfie.dart';
import 'package:facetune/features/scan/domain/entities/selfie_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/analysis_response_fixture.dart';

/// Mirrors `supabase/functions/_shared/storage_ownership.ts`.
///
/// The Edge Function rejects any upload path that does not match this shape
/// with HTTP 403, so a drift between the client's path construction and the
/// server's rule would break every scan in production while passing every
/// per-feature unit test. This reproduces the server rule exactly so the two
/// stay pinned together.
bool isOwnedOriginalPath(String path, String userId, String analysisId) {
  final segments = path.split('/');
  if (segments.length != 5 ||
      segments[0] != userId ||
      segments[1] != 'analyses' ||
      segments[2] != analysisId ||
      segments[3] != 'original') {
    return false;
  }
  final fileName = segments[4];
  final separator = fileName.lastIndexOf('.');
  if (separator <= 0) return false;
  final imageId = fileName.substring(0, separator);
  final extension = fileName.substring(separator + 1).toLowerCase();
  return RegExp(r'^[0-9a-f-]{36}$', caseSensitive: false).hasMatch(imageId) &&
      extension == 'jpg';
}

void main() {
  const selfie = PreparedSelfie(
    originalPath: 'original.jpg',
    uploadPath: 'upload.jpg',
    originalSizeBytes: 2000,
    uploadSizeBytes: 900,
    source: SelfieSource.gallery,
  );
  const validation = LocalImageValidation(
    mimeType: 'image/jpeg',
    width: 1080,
    height: 1440,
    originalSizeBytes: 2000,
    uploadSizeBytes: 900,
  );

  test('the client uploads to a path the Edge Function accepts', () async {
    final remote = _CapturingRemoteDataSource(userId: 'user-42');
    final repository = SupabaseFaceAnalysisRepository(remote);

    await repository.analyze(
      selfie: selfie,
      localValidation: validation,
      onProgress: (_) {},
    );

    expect(remote.uploadPath, isNotNull);
    // Upload target and the path handed to the function must be identical;
    // otherwise the function validates one object and reads another.
    expect(remote.invokedPath, remote.uploadPath);
    expect(
      isOwnedOriginalPath(remote.uploadPath!, 'user-42', remote.invokedId!),
      isTrue,
      reason:
          'Path ${remote.uploadPath} is rejected by the Edge Function rule.',
    );
  });

  test('the upload path is scoped to the calling account', () async {
    final remote = _CapturingRemoteDataSource(userId: 'user-42');
    final repository = SupabaseFaceAnalysisRepository(remote);

    await repository.analyze(
      selfie: selfie,
      localValidation: validation,
      onProgress: (_) {},
    );

    expect(remote.uploadPath, startsWith('user-42/'));
    // Another account's prefix must never validate, which is what stops one
    // user from pointing the function at another user's storage folder.
    expect(
      isOwnedOriginalPath(remote.uploadPath!, 'intruder', remote.invokedId!),
      isFalse,
    );
  });

  test('each scan gets its own analysis and image identifiers', () async {
    final first = _CapturingRemoteDataSource(userId: 'user-42');
    final second = _CapturingRemoteDataSource(userId: 'user-42');

    await SupabaseFaceAnalysisRepository(
      first,
    ).analyze(selfie: selfie, localValidation: validation, onProgress: (_) {});
    await SupabaseFaceAnalysisRepository(
      second,
    ).analyze(selfie: selfie, localValidation: validation, onProgress: (_) {});

    // Reused identifiers would collide on the unique storage_path constraint
    // and let a new scan overwrite an earlier original.
    expect(first.invokedId, isNot(second.invokedId));
    expect(first.uploadPath, isNot(second.uploadPath));
  });

  test('the ownership rule rejects traversal and misplaced objects', () {
    const user = 'user-42';
    const analysis = '8ad50d8d-ff1c-4b1f-a376-58642328f463';
    const image = '3f2a1b4c-5d6e-4f70-8a91-b2c3d4e5f607';

    expect(
      isOwnedOriginalPath(
        '$user/analyses/$analysis/original/$image.jpg',
        user,
        analysis,
      ),
      isTrue,
    );
    expect(
      isOwnedOriginalPath(
        '$user/analyses/$analysis/original/../../../other/$image.jpg',
        user,
        analysis,
      ),
      isFalse,
    );
    expect(
      isOwnedOriginalPath(
        '$user/analyses/$analysis/generated/$image.jpg',
        user,
        analysis,
      ),
      isFalse,
    );
  });
}

class _CapturingRemoteDataSource implements AnalysisRemoteDataSource {
  _CapturingRemoteDataSource({required this.userId});

  final String userId;
  String? uploadPath;
  String? invokedPath;
  String? invokedId;

  @override
  String? get currentUserId => userId;

  @override
  Future<void> uploadSelfie({
    required String localPath,
    required String storagePath,
  }) async {
    uploadPath = storagePath;
  }

  @override
  Future<Object?> invokeAnalysis({
    required String analysisId,
    required String storagePath,
    required LocalImageValidation localValidation,
  }) async {
    invokedId = analysisId;
    invokedPath = storagePath;
    return validAnalysisResponse;
  }
}
