import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/avatar_image.dart';
import '../../domain/errors/profile_failure.dart';
import '../../domain/services/avatar_picker.dart';

class DeviceAvatarPicker implements AvatarPicker {
  DeviceAvatarPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  static const maximumOutputBytes = 2 * 1024 * 1024;
  final ImagePicker _picker;

  @override
  Future<AvatarImage?> pick() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 92,
        requestFullMetadata: false,
      );
      if (image == null) return null;
      final source = await image.readAsBytes();
      if (source.isEmpty) {
        throw const ProfileFailure(
          'That profile photo is empty. Choose another image.',
        );
      }
      var output = await _compress(source, quality: 88);
      if (output.length > maximumOutputBytes) {
        output = await _compress(source, quality: 72);
      }
      if (output.isEmpty || output.length > maximumOutputBytes) {
        throw const ProfileFailure(
          'Choose a profile photo that can be prepared under 2 MB.',
        );
      }
      return AvatarImage(output);
    } on ProfileFailure {
      rethrow;
    } on PlatformException {
      throw const ProfileFailure(
        'FaceTune could not open your photo library. Please try again.',
      );
    } catch (_) {
      throw const ProfileFailure(
        'That profile photo could not be prepared. Choose another image.',
      );
    }
  }

  Future<Uint8List> _compress(Uint8List source, {required int quality}) =>
      FlutterImageCompress.compressWithList(
        source,
        minWidth: 768,
        minHeight: 768,
        quality: quality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
}
