import 'dart:async';

import 'package:facetune/features/makeup_kit/domain/entities/kit_generated_preview.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_look_result.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_library_repository.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_history_controller.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_library_state.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_result_actions_controller.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_saved_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'saved-look loading converts an unexpected failure into safe state',
    () async {
      final controller = MakeupKitSavedController(
        _ResilienceRepository(loadError: StateError('database internals')),
      );
      addTearDown(controller.dispose);

      await controller.loadInitial();

      expect(controller.state.status, MakeupKitLibraryStatus.failure);
      expect(controller.state.items, isEmpty);
      expect(controller.state.message, isNot(contains('database internals')));
    },
  );

  test(
    'history loading converts an unexpected failure into safe state',
    () async {
      final controller = MakeupKitHistoryController(
        _ResilienceRepository(loadError: StateError('database internals')),
        () {},
      );
      addTearDown(controller.dispose);

      await controller.loadInitial();

      expect(controller.state.status, MakeupKitLibraryStatus.failure);
      expect(controller.state.items, isEmpty);
      expect(controller.state.message, isNot(contains('database internals')));
    },
  );

  test(
    'save timeout clears the mutation lock and provides retry feedback',
    () async {
      final repository = _ResilienceRepository(pendingSave: Completer());
      final controller = MakeupKitResultActionsController(
        repository,
        () {},
        timeout: const Duration(milliseconds: 1),
      );
      addTearDown(controller.dispose);

      await controller.toggleSaved(_preview);

      expect(controller.state.isMutating, isFalse);
      expect(controller.state.feedback, contains('too long'));
    },
  );

  test('duplicate save taps issue one repository mutation', () async {
    final pending = Completer<KitSavedLook>();
    final repository = _ResilienceRepository(pendingSave: pending);
    final controller = MakeupKitResultActionsController(repository, () {});

    final first = controller.toggleSaved(_preview);
    final second = controller.toggleSaved(_preview);
    expect(repository.saveCalls, 1);

    controller.dispose();
    pending.completeError(StateError('cancelled after account change'));
    await Future.wait([first, second]);
  });
}

final _preview = KitGeneratedPreview(
  id: '44444444-4444-4444-8444-444444444444',
  analysisId: '33333333-3333-4333-8333-333333333333',
  kitRecommendationId: '22222222-2222-4222-8222-222222222222',
  originalImagePath: 'user/analyses/analysis/original/image.jpg',
  generatedImagePath: 'user/analyses/analysis/kit-generated/preview.png',
  originalImageUrl: 'https://signed.example/original',
  generatedImageUrl: 'https://signed.example/preview',
  generationNumber: 1,
  modelId: 'model',
  promptVersion: 'prompt',
  createdAt: DateTime.utc(2026, 8, 14),
);

class _ResilienceRepository implements MakeupKitLibraryRepository {
  _ResilienceRepository({this.loadError, this.pendingSave});

  final Object? loadError;
  final Completer<KitSavedLook>? pendingSave;
  int saveCalls = 0;

  @override
  Future<KitSavedLooksPageResult> loadSavedPage({
    required int offset,
    required int limit,
  }) async {
    if (loadError != null) throw loadError!;
    return const KitSavedLooksPageResult(items: [], hasMore: false);
  }

  @override
  Future<KitHistoryPageResult> loadHistoryPage({
    required int offset,
    required int limit,
  }) async {
    if (loadError != null) throw loadError!;
    return const KitHistoryPageResult(items: [], hasMore: false);
  }

  @override
  Future<KitSavedLook> save(
    KitGeneratedPreview preview, {
    bool favorite = false,
  }) {
    saveCalls++;
    return pendingSave?.future ?? Future.error(StateError('not configured'));
  }

  @override
  Future<void> deleteSession(String analysisId) async {}

  @override
  Future<KitSavedLook?> findSaved(String kitGeneratedImageId) async => null;

  @override
  Future<void> removeSaved(String savedLookId) async {}

  @override
  Future<KitSavedLook> setFavorite(KitSavedLook look, bool isFavorite) async =>
      look;
}
