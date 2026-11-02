import '../entities/custom_palette_look.dart';
import '../validation/custom_palette_contract.dart';

/// A request that could not be completed.
class CustomPaletteFailure implements Exception {
  const CustomPaletteFailure(
    this.message, {
    this.retryable = false,
    this.code,
    this.requestEnded = true,
    this.sessionExpired = false,
  });

  /// Safe to show to the user.
  final String message;
  final bool retryable;

  /// The server's sanitized code, when it gave one.
  final String? code;

  /// False when the outcome is unknown or still running: the connection dropped,
  /// or another invocation is working on this operation. The same operation id
  /// must then be replayed, so one request can never become a second charge.
  final bool requestEnded;
  final bool sessionExpired;
}

/// The authenticated server path for a frozen palette.
///
/// The client hands over the canonical request and nothing else. It never writes
/// palette, recommendation or preview rows itself.
abstract interface class CustomPaletteGateway {
  /// Freezes [request] and returns the palette with its plan.
  Future<CustomPaletteRecommendation> submit(CustomPaletteRequest request);

  /// Runs or resumes one logical preview request for [recommendation].
  ///
  /// [operationId] is what makes this safe to repeat.
  Future<CustomPaletteGeneratedPreview> generatePreview({
    required CustomPaletteRecommendation recommendation,
    required String operationId,
  });
}

/// The user's generated Custom Color Palette looks.
abstract interface class CustomPaletteLibraryRepository {
  Future<CustomPaletteSavedLook?> findSaved(String previewId);

  Future<CustomPaletteSavedLook> save(
    CustomPaletteGeneratedPreview preview, {
    bool favorite = false,
  });

  Future<CustomPaletteSavedLook> setFavorite(
    CustomPaletteSavedLook look,
    bool isFavorite,
  );

  Future<void> removeSaved(String savedLookId);

  Future<CustomPalettePage<CustomPaletteSavedLook>> loadSavedPage({
    required int offset,
    required int limit,
  });

  Future<CustomPalettePage<CustomPaletteHistoryEntry>> loadHistoryPage({
    required int offset,
    required int limit,
  });

  /// Deletes the whole analysis session, through the existing history path.
  Future<void> deleteSession(String analysisId);
}
