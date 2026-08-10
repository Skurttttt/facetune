import 'dart:typed_data';

import '../errors/selfie_failure.dart';

class SelfieFileValidator {
  const SelfieFileValidator({this.maximumBytes = 20 * 1024 * 1024});

  final int maximumBytes;

  void validate({
    required String path,
    required int size,
    required Uint8List header,
  }) {
    if (size <= 0) {
      throw const SelfieFailure(
        SelfieFailureType.unreadableFile,
        'That image is empty or unreadable. Choose another photo.',
      );
    }
    if (size > maximumBytes) {
      throw const SelfieFailure(
        SelfieFailureType.fileTooLarge,
        'That image is too large. Choose a photo under 20 MB.',
      );
    }
    if (!_hasSupportedExtension(path) || !_hasSupportedSignature(header)) {
      throw const SelfieFailure(
        SelfieFailureType.unsupportedType,
        'Choose a JPEG, PNG, WebP, HEIC, or HEIF image.',
      );
    }
  }

  bool _hasSupportedExtension(String path) {
    final extension = path.toLowerCase().split('.').last;
    return const {
      'jpg',
      'jpeg',
      'png',
      'webp',
      'heic',
      'heif',
    }.contains(extension);
  }

  bool _hasSupportedSignature(Uint8List bytes) {
    if (bytes.length < 12) return false;
    final isJpeg = bytes[0] == 0xff && bytes[1] == 0xd8;
    final isPng =
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47;
    final isWebP =
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
    final brand = String.fromCharCodes(bytes.sublist(4, 12)).toLowerCase();
    final isHeif =
        brand.startsWith('ftyp') &&
        (brand.contains('heic') ||
            brand.contains('heix') ||
            brand.contains('hevc') ||
            brand.contains('hevx') ||
            brand.contains('mif1') ||
            brand.contains('msf1'));
    return isJpeg || isPng || isWebP || isHeif;
  }
}
