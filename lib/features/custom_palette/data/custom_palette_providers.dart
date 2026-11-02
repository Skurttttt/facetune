import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_availability_provider.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/entities/custom_palette_look.dart';
import '../domain/repositories/custom_palette_gateway.dart';
import '../domain/validation/custom_palette_contract.dart';
import 'custom_palette_remote_data_source.dart';
import 'supabase_custom_palette_repository.dart';

/// Refuses every generation in a build with no server configured.
class UnavailableCustomPaletteGateway implements CustomPaletteGateway {
  const UnavailableCustomPaletteGateway();

  static const _failure = CustomPaletteFailure(
    'Custom Color Palette looks are not available in this build.',
  );

  @override
  Future<CustomPaletteRecommendation> submit(
    CustomPaletteRequest request,
  ) async => throw _failure;

  @override
  Future<CustomPaletteGeneratedPreview> generatePreview({
    required CustomPaletteRecommendation recommendation,
    required String operationId,
  }) async => throw _failure;
}

/// An empty library, so an unconfigured build shows no error on shared pages.
class UnavailableCustomPaletteLibrary
    implements CustomPaletteLibraryRepository {
  const UnavailableCustomPaletteLibrary();

  static const _failure = CustomPaletteFailure(
    'Custom Color Palette looks are not available in this build.',
  );

  @override
  Future<CustomPaletteSavedLook?> findSaved(String previewId) async => null;

  @override
  Future<CustomPaletteSavedLook> save(
    CustomPaletteGeneratedPreview preview, {
    bool favorite = false,
  }) async => throw _failure;

  @override
  Future<CustomPaletteSavedLook> setFavorite(
    CustomPaletteSavedLook look,
    bool isFavorite,
  ) async => throw _failure;

  @override
  Future<void> removeSaved(String savedLookId) async => throw _failure;

  @override
  Future<CustomPalettePage<CustomPaletteSavedLook>> loadSavedPage({
    required int offset,
    required int limit,
  }) async => const CustomPalettePage(items: [], hasMore: false);

  @override
  Future<CustomPalettePage<CustomPaletteHistoryEntry>> loadHistoryPage({
    required int offset,
    required int limit,
  }) async => const CustomPalettePage(items: [], hasMore: false);

  @override
  Future<void> deleteSession(String analysisId) async => throw _failure;
}

final _customPaletteRepositoryProvider =
    Provider<SupabaseCustomPaletteRepository>(
      (ref) => SupabaseCustomPaletteRepository(
        SupabaseCustomPaletteRemoteDataSource(
          ref.watch(supabaseClientProvider),
        ),
      ),
    );

final customPaletteGatewayProvider = Provider<CustomPaletteGateway>((ref) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const UnavailableCustomPaletteGateway();
  }
  return ref.watch(_customPaletteRepositoryProvider);
});

final customPaletteLibraryRepositoryProvider =
    Provider<CustomPaletteLibraryRepository>((ref) {
      if (!ref.watch(supabaseAvailableProvider)) {
        return const UnavailableCustomPaletteLibrary();
      }
      return ref.watch(_customPaletteRepositoryProvider);
    });

/// Bumped when a look is saved or removed, so every library view reloads.
final customPaletteLibraryRevisionProvider = StateProvider<int>((ref) => 0);
