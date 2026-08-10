import 'dart:typed_data';

import '../errors/selfie_failure.dart';

class SelfieFileValidator {
  const SelfieFileValidator({this.maximumBytes = 20 * 1024 * 1024});

  final int maximumBytes;

  String validate({
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
    final mimeType = detectMimeType(header);
    if (!_extensionMatchesMime(path, mimeType)) {
      throw const SelfieFailure(
        SelfieFailureType.unsupportedType,
        'Choose a JPEG, PNG, WebP, HEIC, or HEIF image.',
      );
    }
    return mimeType!;
  }

  bool _extensionMatchesMime(String path, String? mimeType) {
    if (mimeType == null) return false;
    final extension = path.toLowerCase().split('.').last;
    return switch (mimeType) {
      'image/jpeg' => extension == 'jpg' || extension == 'jpeg',
      'image/png' => extension == 'png',
      'image/webp' => extension == 'webp',
      'image/heic' => extension == 'heic' || extension == 'heif',
      _ => false,
    };
  }

  String? detectMimeType(Uint8List bytes) {
    if (bytes.length < 12) return null;
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
    if (isJpeg) return 'image/jpeg';
    if (isPng) return 'image/png';
    if (isWebP) return 'image/webp';
    if (isHeif) return 'image/heic';
    return null;
  }
}
