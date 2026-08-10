import 'package:facetune/features/scan/domain/entities/local_image_validation.dart';
import 'package:facetune/features/scan/domain/entities/prepared_selfie.dart';
import 'package:facetune/features/scan/domain/entities/selfie_source.dart';
import 'package:facetune/features/scan/domain/errors/image_validation_failure.dart';
import 'package:facetune/features/scan/domain/errors/selfie_failure.dart';
import 'package:facetune/features/scan/domain/repositories/image_validation_repository.dart';
import 'package:facetune/features/scan/domain/repositories/selfie_repository.dart';
import 'package:facetune/features/scan/presentation/controllers/scan_controller.dart';
import 'package:facetune/features/scan/presentation/controllers/scan_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const selfie = PreparedSelfie(
    originalPath: 'original.jpg',
    uploadPath: 'upload.jpg',
    originalSizeBytes: 100,
    uploadSizeBytes: 70,
    source: SelfieSource.gallery,
  );
  const validImage = LocalImageValidation(
    mimeType: 'image/jpeg',
    width: 1080,
    height: 1440,
    originalSizeBytes: 100,
    uploadSizeBytes: 70,
  );

  test('selected selfie becomes preview ready', () async {
    final repository = _FakeSelfieRepository(result: selfie);
    final controller = _controller(repository);

    await controller.chooseFromGallery();

    expect(controller.state.stage, ScanStage.previewReady);
    expect(controller.state.selfie, same(selfie));
  });

  test('replacement discards prior local files only after success', () async {
    final repository = _FakeSelfieRepository(result: selfie);
    final controller = _controller(repository);
    await controller.chooseFromGallery();
    const replacement = PreparedSelfie(
      originalPath: 'replacement.png',
      uploadPath: 'replacement-upload.jpg',
      originalSizeBytes: 80,
      uploadSizeBytes: 60,
      source: SelfieSource.gallery,
    );
    repository.result = replacement;

    await controller.chooseFromGallery();

    expect(repository.discarded, contains(same(selfie)));
    expect(controller.state.selfie, same(replacement));
  });

  test('permanent denial keeps preview and offers settings', () async {
    final repository = _FakeSelfieRepository(result: selfie);
    final controller = _controller(repository);
    await controller.chooseFromGallery();
    repository.failure = const SelfieFailure(
      SelfieFailureType.permissionPermanentlyDenied,
      'Open settings.',
    );

    await controller.takePhoto();

    expect(controller.state.selfie, same(selfie));
    expect(controller.state.canOpenSettings, isTrue);
    expect(controller.state.errorMessage, 'Open settings.');
  });

  test('successful local validation is ready for secure validation', () async {
    final controller = _controller(
      _FakeSelfieRepository(result: selfie),
      validationResult: validImage,
    );
    await controller.chooseFromGallery();

    await controller.validateForAnalysis();

    expect(controller.state.stage, ScanStage.readyForSecureValidation);
    expect(controller.state.localValidation, same(validImage));
  });

  test('validation failure keeps selfie and exposes retry', () async {
    const failure = ImageValidationFailure(
      ImageValidationFailureType.corruptImage,
      'Image is corrupt.',
    );
    final controller = _controller(
      _FakeSelfieRepository(result: selfie),
      validationFailure: failure,
    );
    await controller.chooseFromGallery();

    await controller.validateForAnalysis();

    expect(controller.state.stage, ScanStage.validationFailed);
    expect(controller.state.selfie, same(selfie));
    expect(controller.state.canRetryValidation, isTrue);
    expect(controller.state.errorMessage, failure.message);
  });
}

ScanController _controller(
  _FakeSelfieRepository repository, {
  LocalImageValidation? validationResult,
  ImageValidationFailure? validationFailure,
}) {
  return ScanController(
    selfieRepository: repository,
    validationRepository: _FakeImageValidationRepository(
      result:
          validationResult ??
          const LocalImageValidation(
            mimeType: 'image/jpeg',
            width: 1080,
            height: 1440,
            originalSizeBytes: 100,
            uploadSizeBytes: 70,
          ),
      failure: validationFailure,
    ),
  );
}

class _FakeSelfieRepository implements SelfieRepository {
  _FakeSelfieRepository({this.result});

  PreparedSelfie? result;
  SelfieFailure? failure;
  final discarded = <PreparedSelfie>[];

  @override
  Future<PreparedSelfie?> acquire(SelfieSource source) async {
    final currentFailure = failure;
    if (currentFailure != null) throw currentFailure;
    return result;
  }

  @override
  Future<void> discard(PreparedSelfie selfie) async => discarded.add(selfie);

  @override
  Future<bool> openPermissionSettings() async => true;
}

class _FakeImageValidationRepository implements ImageValidationRepository {
  const _FakeImageValidationRepository({required this.result, this.failure});

  final LocalImageValidation result;
  final ImageValidationFailure? failure;

  @override
  Future<LocalImageValidation> validateLocal(PreparedSelfie selfie) async {
    final currentFailure = failure;
    if (currentFailure != null) throw currentFailure;
    return result;
  }
}
