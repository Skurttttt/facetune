import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/entities/prepared_selfie.dart';
import '../../domain/entities/selfie_source.dart';
import '../../domain/errors/selfie_failure.dart';
import '../../domain/repositories/selfie_repository.dart';
import '../../domain/services/selfie_file_validator.dart';

class DeviceSelfieRepository implements SelfieRepository {
  DeviceSelfieRepository({
    ImagePicker? picker,
    SelfieFileValidator validator = const SelfieFileValidator(),
  }) : _picker = picker ?? ImagePicker(),
       _validator = validator;

  final ImagePicker _picker;
  final SelfieFileValidator _validator;

  @override
  Future<PreparedSelfie?> acquire(SelfieSource source) async {
    try {
      if (source == SelfieSource.camera) {
        await _requireCameraPermission();
      }
      final selected = await _picker.pickImage(
        source: source == SelfieSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.front,
        requestFullMetadata: false,
      );
      if (selected == null) return null;
      return _prepare(selected, source);
    } on SelfieFailure {
      rethrow;
    } on PlatformException catch (error) {
      throw _mapPlatformFailure(error);
    } on FileSystemException {
      throw const SelfieFailure(
        SelfieFailureType.unreadableFile,
        'FaceTune could not read that image. Choose another photo.',
      );
    } catch (_) {
      throw const SelfieFailure(
        SelfieFailureType.preparationFailed,
        'FaceTune could not prepare that selfie. Please try another image.',
      );
    }
  }

  Future<PreparedSelfie> _prepare(XFile selected, SelfieSource source) async {
    final sourceFile = File(selected.path);
    final size = await sourceFile.length();
    final randomAccessFile = await sourceFile.open();
    late final List<int> header;
    try {
      header = await randomAccessFile.read(16);
    } finally {
      await randomAccessFile.close();
    }
    _validator.validate(path: selected.path, size: size, header: header);

    final sessionDirectory = Directory(
      path.join((await getTemporaryDirectory()).path, 'facetune', 'selfies'),
    );
    await sessionDirectory.create(recursive: true);
    final id =
        '${DateTime.now().microsecondsSinceEpoch}_${size.hashCode.abs()}';
    final extension = path.extension(selected.path).toLowerCase();
    final originalPath = path.join(
      sessionDirectory.path,
      '${id}_original$extension',
    );
    final uploadPath = path.join(sessionDirectory.path, '${id}_upload.jpg');

    File? original;
    try {
      original = await sourceFile.copy(originalPath);
      final compressed = await FlutterImageCompress.compressAndGetFile(
        original.path,
        uploadPath,
        minWidth: 2048,
        minHeight: 2048,
        quality: 88,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (compressed == null) {
        throw const SelfieFailure(
          SelfieFailureType.preparationFailed,
          'FaceTune could not prepare that selfie. Please try another image.',
        );
      }
      final uploadSize = await compressed.length();
      if (uploadSize <= 0) {
        throw const SelfieFailure(
          SelfieFailureType.preparationFailed,
          'The prepared selfie is unreadable. Please try another image.',
        );
      }
      return PreparedSelfie(
        originalPath: original.path,
        uploadPath: compressed.path,
        originalSizeBytes: size,
        uploadSizeBytes: uploadSize,
        source: source,
      );
    } catch (_) {
      if (original != null && await original.exists()) await original.delete();
      final upload = File(uploadPath);
      if (await upload.exists()) await upload.delete();
      rethrow;
    }
  }

  Future<void> _requireCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isGranted) return;
    status = await Permission.camera.request();
    if (status.isGranted) return;
    if (status.isPermanentlyDenied || status.isRestricted) {
      throw const SelfieFailure(
        SelfieFailureType.permissionPermanentlyDenied,
        'Camera access is blocked. Open Settings to allow camera access.',
      );
    }
    throw const SelfieFailure(
      SelfieFailureType.permissionDenied,
      'Camera access was denied. You can try again or choose from your gallery.',
    );
  }

  SelfieFailure _mapPlatformFailure(PlatformException error) {
    final code = error.code.toLowerCase();
    if (code.contains('camera_access_denied')) {
      return const SelfieFailure(
        SelfieFailureType.permissionDenied,
        'Camera access was denied. You can try again or choose from your gallery.',
      );
    }
    if (code.contains('camera_access_restricted')) {
      return const SelfieFailure(
        SelfieFailureType.permissionPermanentlyDenied,
        'Camera access is blocked. Open Settings to allow camera access.',
      );
    }
    return const SelfieFailure(
      SelfieFailureType.preparationFailed,
      'FaceTune could not open that image source. Please try again.',
    );
  }

  @override
  Future<bool> openPermissionSettings() => openAppSettings();

  @override
  Future<void> discard(PreparedSelfie selfie) async {
    for (final filePath in {selfie.originalPath, selfie.uploadPath}) {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    }
  }
}
