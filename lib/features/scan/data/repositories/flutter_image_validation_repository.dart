import 'dart:io';
import 'dart:ui' as ui;

import '../../domain/entities/local_image_validation.dart';
import '../../domain/entities/prepared_selfie.dart';
import '../../domain/errors/image_validation_failure.dart';
import '../../domain/errors/selfie_failure.dart';
import '../../domain/repositories/image_validation_repository.dart';
import '../../domain/services/selfie_file_validator.dart';

class FlutterImageValidationRepository implements ImageValidationRepository {
  const FlutterImageValidationRepository({
    SelfieFileValidator originalValidator = const SelfieFileValidator(),
    SelfieFileValidator uploadValidator = const SelfieFileValidator(
      maximumBytes: 10 * 1024 * 1024,
    ),
  }) : _originalValidator = originalValidator,
       _uploadValidator = uploadValidator;

  static const minimumDimension = 480;
  static const maximumDimension = 12000;
  static const maximumPixels = 80000000;
  static const minimumAspectRatio = 0.4;
  static const maximumAspectRatio = 2.5;

  final SelfieFileValidator _originalValidator;
  final SelfieFileValidator _uploadValidator;

  @override
  Future<LocalImageValidation> validateLocal(PreparedSelfie selfie) async {
    final original = await _inspect(
      selfie.originalPath,
      _originalValidator,
      expectedMimeType: null,
    );
    final upload = await _inspect(
      selfie.uploadPath,
      _uploadValidator,
      expectedMimeType: 'image/jpeg',
    );
    _validateDimensions(original.width, original.height);
    _validateDimensions(upload.width, upload.height);
    return LocalImageValidation(
      mimeType: upload.mimeType,
      width: upload.width,
      height: upload.height,
      originalSizeBytes: original.size,
      uploadSizeBytes: upload.size,
    );
  }

  Future<_InspectedImage> _inspect(
    String filePath,
    SelfieFileValidator validator, {
    required String? expectedMimeType,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const ImageValidationFailure(
        ImageValidationFailureType.missingFile,
        'The selected image is no longer available. Please choose it again.',
      );
    }

    try {
      final size = await file.length();
      final bytes = await file.readAsBytes();
      final mimeType = validator.validate(
        path: filePath,
        size: size,
        header: bytes.length > 16 ? bytes.sublist(0, 16) : bytes,
      );
      if (expectedMimeType != null && mimeType != expectedMimeType) {
        throw const ImageValidationFailure(
          ImageValidationFailureType.unsupportedType,
          'The prepared image has an unsupported format. Please reselect it.',
        );
      }
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        final width = frame.image.width;
        final height = frame.image.height;
        frame.image.dispose();
        return _InspectedImage(
          mimeType: mimeType,
          width: width,
          height: height,
          size: size,
        );
      } finally {
        codec.dispose();
      }
    } on ImageValidationFailure {
      rethrow;
    } on SelfieFailure catch (failure) {
      throw _mapFileFailure(failure);
    } on FileSystemException {
      throw const ImageValidationFailure(
        ImageValidationFailureType.missingFile,
        'FaceTune could not read that image. Please choose it again.',
      );
    } catch (_) {
      throw const ImageValidationFailure(
        ImageValidationFailureType.corruptImage,
        'That image is damaged or cannot be decoded. Choose another photo.',
      );
    }
  }

  void _validateDimensions(int width, int height) {
    if (width < minimumDimension || height < minimumDimension) {
      throw const ImageValidationFailure(
        ImageValidationFailureType.dimensionsTooSmall,
        'That image is too small. Choose one at least 480 × 480 pixels.',
      );
    }
    if (width > maximumDimension ||
        height > maximumDimension ||
        width * height > maximumPixels) {
      throw const ImageValidationFailure(
        ImageValidationFailureType.dimensionsTooLarge,
        'That image has unusually large dimensions. Choose a smaller photo.',
      );
    }
    final aspectRatio = width / height;
    if (aspectRatio < minimumAspectRatio || aspectRatio > maximumAspectRatio) {
      throw const ImageValidationFailure(
        ImageValidationFailureType.extremeAspectRatio,
        'That image is unusually narrow or wide. Choose a normal selfie crop.',
      );
    }
  }

  ImageValidationFailure _mapFileFailure(SelfieFailure failure) {
    return switch (failure.type) {
      SelfieFailureType.unsupportedType => const ImageValidationFailure(
        ImageValidationFailureType.unsupportedType,
        'Choose a supported JPEG, PNG, WebP, HEIC, or HEIF image.',
      ),
      SelfieFailureType.fileTooLarge => const ImageValidationFailure(
        ImageValidationFailureType.fileTooLarge,
        'That image is too large. Choose a smaller photo.',
      ),
      SelfieFailureType.unreadableFile => const ImageValidationFailure(
        ImageValidationFailureType.emptyFile,
        'That image is empty or unreadable. Choose another photo.',
      ),
      _ => const ImageValidationFailure(
        ImageValidationFailureType.corruptImage,
        'That image cannot be validated. Choose another photo.',
      ),
    };
  }
}

class _InspectedImage {
  const _InspectedImage({
    required this.mimeType,
    required this.width,
    required this.height,
    required this.size,
  });

  final String mimeType;
  final int width;
  final int height;
  final int size;
}
