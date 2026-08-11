import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../preview/domain/entities/generated_preview.dart';
import '../../domain/services/result_share_service.dart';

class NativeResultShareService implements ResultShareService {
  const NativeResultShareService();

  static const _maximumShareBytes = 15 * 1024 * 1024;

  @override
  Future<void> share({
    required GeneratedPreview preview,
    required String styleName,
  }) async {
    final uri = Uri.tryParse(preview.generatedImageUrl);
    if (uri == null || uri.scheme != 'https') {
      throw const ResultShareFailure('The private preview link is invalid.');
    }
    File? temporaryFile;
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw const ResultShareFailure(
          'The preview could not be prepared for sharing.',
        );
      }
      final directory = await getTemporaryDirectory();
      final extension = _safeExtension(preview.generatedImagePath);
      temporaryFile = File(
        path.join(directory.path, 'facetune_${preview.id}.$extension'),
      );
      final sink = temporaryFile.openWrite();
      var byteCount = 0;
      try {
        await for (final chunk in response) {
          byteCount += chunk.length;
          if (byteCount > _maximumShareBytes) {
            throw const ResultShareFailure(
              'The preview is too large to share safely.',
            );
          }
          sink.add(chunk);
        }
      } finally {
        await sink.close();
      }
      if (byteCount == 0) {
        throw const ResultShareFailure(
          'The preview could not be prepared for sharing.',
        );
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(temporaryFile.path, mimeType: _mimeType(extension))],
          text: 'My $styleName makeup look, created with FaceTune.',
          subject: 'My FaceTune makeup look',
        ),
      );
    } on ResultShareFailure {
      rethrow;
    } catch (_) {
      throw const ResultShareFailure(
        'Sharing is unavailable right now. Please try again.',
      );
    } finally {
      client.close(force: true);
      final file = temporaryFile;
      if (file != null && await file.exists()) await file.delete();
    }
  }

  static String _safeExtension(String storagePath) {
    final extension = path.extension(storagePath).toLowerCase();
    return switch (extension) {
      '.jpg' || '.jpeg' => 'jpg',
      '.webp' => 'webp',
      _ => 'png',
    };
  }

  static String _mimeType(String extension) => switch (extension) {
    'jpg' => 'image/jpeg',
    'webp' => 'image/webp',
    _ => 'image/png',
  };
}
