import 'dart:async';
import 'dart:io';

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

  test('validation failure keeps selfie and requires reselection', () async {
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
    expect(controller.state.canRetryValidation, isFalse);
    expect(controller.state.canReselect, isTrue);
    expect(controller.state.errorMessage, failure.message);
  });

  test(
    'canceling replacement preserves the complete validated state',
    () async {
      final repository = _FakeSelfieRepository(result: selfie);
      final controller = _controller(repository, validationResult: validImage);
      await controller.chooseFromGallery();
      await controller.validateForAnalysis();
      repository.result = null;

      final changed = await controller.chooseFromGallery();

      expect(changed, isFalse);
      expect(controller.state.stage, ScanStage.readyForSecureValidation);
      expect(controller.state.selfie, same(selfie));
      expect(controller.state.localValidation, same(validImage));
    },
  );

  test('cleanup failure does not reject a successful replacement', () async {
    final repository = _FakeSelfieRepository(result: selfie);
    final controller = _controller(repository);
    await controller.chooseFromGallery();
    const replacement = PreparedSelfie(
      originalPath: 'replacement.jpg',
      uploadPath: 'replacement-upload.jpg',
      originalSizeBytes: 80,
      uploadSizeBytes: 60,
      source: SelfieSource.gallery,
    );
    repository
      ..result = replacement
      ..discardFailure = const FileSystemException('locked');

    final changed = await controller.chooseFromGallery();

    expect(changed, isTrue);
    expect(controller.state.stage, ScanStage.previewReady);
    expect(controller.state.selfie, same(replacement));
    expect(controller.state.isBusy, isFalse);
  });

  test(
    'unexpected acquisition error never leaves the controller busy',
    () async {
      final repository = _FakeSelfieRepository(
        unexpectedFailure: StateError('plugin failure'),
      );
      final controller = _controller(repository);

      await controller.chooseFromGallery();

      expect(controller.state.stage, ScanStage.idle);
      expect(controller.state.isBusy, isFalse);
      expect(controller.state.errorMessage, contains('could not open'));
      expect(controller.state.errorMessage, isNot(contains('plugin failure')));
    },
  );

  test(
    'beginning a new scan discards an acquisition that completes late',
    () async {
      final pending = Completer<PreparedSelfie?>();
      final repository = _FakeSelfieRepository(acquireCompleter: pending);
      final controller = _controller(repository);

      final acquisition = controller.chooseFromGallery();
      await Future<void>.delayed(Duration.zero);
      await controller.beginNewScan();
      pending.complete(selfie);
      await acquisition;

      expect(controller.state.stage, ScanStage.idle);
      expect(controller.state.selfie, isNull);
      expect(repository.discarded, contains(same(selfie)));
    },
  );

  test(
    'beginning a new scan ignores local validation that completes late',
    () async {
      final pending = Completer<LocalImageValidation>();
      final repository = _FakeSelfieRepository(result: selfie);
      final validationRepository = _FakeImageValidationRepository(
        result: validImage,
        completer: pending,
      );
      final controller = ScanController(
        selfieRepository: repository,
        validationRepository: validationRepository,
      );
      await controller.chooseFromGallery();

      final validation = controller.validateForAnalysis();
      await Future<void>.delayed(Duration.zero);
      await controller.beginNewScan();
      pending.complete(validImage);
      await validation;

      expect(controller.state.stage, ScanStage.idle);
      expect(controller.state.localValidation, isNull);
    },
  );
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
  _FakeSelfieRepository({
    this.result,
    this.unexpectedFailure,
    this.acquireCompleter,
  });

  PreparedSelfie? result;
  SelfieFailure? failure;
  Object? unexpectedFailure;
  Object? discardFailure;
  Completer<PreparedSelfie?>? acquireCompleter;
  final discarded = <PreparedSelfie>[];

  @override
  Future<PreparedSelfie?> acquire(SelfieSource source) async {
    final currentFailure = failure;
    if (currentFailure != null) throw currentFailure;
    final currentUnexpectedFailure = unexpectedFailure;
    if (currentUnexpectedFailure != null) throw currentUnexpectedFailure;
    final currentCompleter = acquireCompleter;
    if (currentCompleter != null) return currentCompleter.future;
    return result;
  }

  @override
  Future<void> discard(PreparedSelfie selfie) async {
    discarded.add(selfie);
    final currentFailure = discardFailure;
    if (currentFailure != null) throw currentFailure;
  }

  @override
  Future<bool> openPermissionSettings() async => true;
}

class _FakeImageValidationRepository implements ImageValidationRepository {
  const _FakeImageValidationRepository({
    required this.result,
    this.failure,
    this.completer,
  });

  final LocalImageValidation result;
  final ImageValidationFailure? failure;
  final Completer<LocalImageValidation>? completer;

  @override
  Future<LocalImageValidation> validateLocal(PreparedSelfie selfie) async {
    final currentFailure = failure;
    if (currentFailure != null) throw currentFailure;
    final currentCompleter = completer;
    if (currentCompleter != null) return currentCompleter.future;
    return result;
  }
}
