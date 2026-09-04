/// Distributes an already-generated result image through the system share
/// sheet.
///
/// The parameters are the four values sharing actually consumes rather than a
/// preview entity. That distinction is the whole reason My Makeup Kit could not
/// share: this took a `GeneratedPreview`, which is Standard Mode's entity, so
/// the kit — whose canonical result is a `KitGeneratedPreview` — had no way in,
/// despite carrying the same three fields with the same meaning.
///
/// Asking for what it uses keeps one share implementation for both modes. The
/// alternative was a second copy of the download, MIME check, size cap and
/// temp-file cleanup, maintained in parallel and drifting.
///
/// This service never creates an image. It is handed one that already exists
/// and moves it; nothing here regenerates, re-requests or re-decides a result.
abstract interface class ResultShareService {
  Future<void> share({
    /// Signed URL of the already-generated preview.
    required String imageUrl,

    /// Storage path of that same object. Used only to pick a file extension.
    required String storagePath,

    /// Identifies the temporary file. Not sent anywhere.
    required String previewId,

    /// The look's style name, for the share text.
    required String styleName,
  });
}

class ResultShareFailure implements Exception {
  const ResultShareFailure(this.message);

  final String message;
}
