import 'package:facetune/features/makeup_kit/domain/entities/kit_generated_preview.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_look_result.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_library_repository.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_result_actions_controller.dart';
import 'package:facetune/features/results/domain/services/result_share_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kit-mode sharing.
///
/// The point of these is that sharing is a *read* of a result that already
/// exists. Standard Mode has shared this way for a while; what was missing was
/// a way for the kit's own canonical preview to reach the same service. These
/// pin that the bridge carries kit values, and only kit values.
final _preview = KitGeneratedPreview(
  id: 'kit-preview-1',
  analysisId: 'analysis-1',
  kitRecommendationId: 'kit-rec-1',
  originalImagePath: 'user/original.png',
  generatedImagePath: 'user/kit-generated.webp',
  originalImageUrl: 'https://example.invalid/kit-original.png',
  generatedImageUrl: 'https://example.invalid/kit-generated.webp',
  generationNumber: 1,
  modelId: 'gemini-3.1-flash-image',
  promptVersion: 'kit-v1',
  createdAt: DateTime.utc(2026, 9, 4),
);

void main() {
  test('share hands the kit canonical preview to the shared service', () async {
    final share = _RecordingShareService();
    final controller = MakeupKitResultActionsController(
      _UnusedRepository(),
      () {},
      shareService: share,
    );
    addTearDown(controller.dispose);

    await controller.share(preview: _preview, styleName: 'Old Money');

    expect(share.calls, 1);
    // The kit's own artifact, not a Standard one and not a regenerated one.
    expect(share.imageUrl, 'https://example.invalid/kit-generated.webp');
    expect(share.storagePath, 'user/kit-generated.webp');
    expect(share.previewId, 'kit-preview-1');
    expect(share.styleName, 'Old Money');

    expect(controller.state.isSharing, isFalse);
    expect(controller.state.feedback, 'Share sheet opened.');
  });

  test('sharing touches no repository operation', () async {
    // The library repository is the only route to saved looks and product
    // records. A share that read or wrote through it would mean sharing had
    // become something other than distributing an existing image.
    final repository = _UnusedRepository();
    final controller = MakeupKitResultActionsController(
      repository,
      () {},
      shareService: _RecordingShareService(),
    );
    addTearDown(controller.dispose);

    await controller.share(preview: _preview, styleName: 'Old Money');

    expect(repository.calls, isEmpty);
  });

  test('a second tap while sharing is ignored', () async {
    final share = _RecordingShareService();
    final controller = MakeupKitResultActionsController(
      _UnusedRepository(),
      () {},
      shareService: share,
    );
    addTearDown(controller.dispose);

    final first = controller.share(preview: _preview, styleName: 'Old Money');
    final second = controller.share(preview: _preview, styleName: 'Old Money');
    await Future.wait(<Future<void>>[first, second]);

    expect(share.calls, 1);
  });

  test('a share failure surfaces its message and clears the lock', () async {
    final controller = MakeupKitResultActionsController(
      _UnusedRepository(),
      () {},
      shareService: _FailingShareService(),
    );
    addTearDown(controller.dispose);

    await controller.share(preview: _preview, styleName: 'Old Money');

    expect(controller.state.isSharing, isFalse);
    expect(controller.state.feedback, 'The private preview link is invalid.');
  });

  test('an unexpected platform error does not leak out', () async {
    final controller = MakeupKitResultActionsController(
      _UnusedRepository(),
      () {},
      shareService: _ExplodingShareService(),
    );
    addTearDown(controller.dispose);

    await controller.share(preview: _preview, styleName: 'Old Money');

    expect(controller.state.isSharing, isFalse);
    expect(
      controller.state.feedback,
      'Sharing is unavailable right now. Please try again.',
    );
  });

  test('sharing leaves the saved and favorite state alone', () async {
    final controller = MakeupKitResultActionsController(
      _UnusedRepository(),
      () {},
      shareService: _RecordingShareService(),
    );
    addTearDown(controller.dispose);

    await controller.share(preview: _preview, styleName: 'Old Money');

    expect(controller.state.savedByPreviewId, isEmpty);
    expect(controller.state.isSaved(_preview.id), isFalse);
    expect(controller.state.isFavorite(_preview.id), isFalse);
    // Sharing must not disable Favorite: they are unrelated operations.
    expect(controller.state.isMutating, isFalse);
  });
}

class _RecordingShareService implements ResultShareService {
  int calls = 0;
  String? imageUrl;
  String? storagePath;
  String? previewId;
  String? styleName;

  @override
  Future<void> share({
    required String imageUrl,
    required String storagePath,
    required String previewId,
    required String styleName,
  }) async {
    calls += 1;
    this.imageUrl = imageUrl;
    this.storagePath = storagePath;
    this.previewId = previewId;
    this.styleName = styleName;
  }
}

class _FailingShareService implements ResultShareService {
  @override
  Future<void> share({
    required String imageUrl,
    required String storagePath,
    required String previewId,
    required String styleName,
  }) async =>
      throw const ResultShareFailure('The private preview link is invalid.');
}

class _ExplodingShareService implements ResultShareService {
  @override
  Future<void> share({
    required String imageUrl,
    required String storagePath,
    required String previewId,
    required String styleName,
  }) => Future<void>.error(StateError('platform detail'));
}

/// Records any repository call so a test can assert none happened.
class _UnusedRepository implements MakeupKitLibraryRepository {
  final List<String> calls = <String>[];

  @override
  Future<KitSavedLook?> findSaved(String previewId) async {
    calls.add('findSaved');
    return null;
  }

  @override
  Future<KitSavedLook> save(
    KitGeneratedPreview preview, {
    bool favorite = false,
  }) {
    calls.add('save');
    throw StateError('Not expected in a share test.');
  }

  @override
  Future<KitSavedLook> setFavorite(KitSavedLook look, bool favorite) {
    calls.add('setFavorite');
    throw StateError('Not expected in a share test.');
  }

  @override
  Future<void> removeSaved(String savedLookId) async {
    calls.add('removeSaved');
  }

  @override
  Future<KitSavedLooksPageResult> loadSavedPage({
    required int offset,
    required int limit,
  }) async {
    calls.add('loadSavedPage');
    return const KitSavedLooksPageResult(
      items: <KitSavedLook>[],
      hasMore: false,
    );
  }

  @override
  Future<KitHistoryPageResult> loadHistoryPage({
    required int offset,
    required int limit,
  }) async {
    calls.add('loadHistoryPage');
    return const KitHistoryPageResult(
      items: <KitHistoryEntry>[],
      hasMore: false,
    );
  }

  @override
  Future<void> deleteSession(String analysisId) async {
    calls.add('deleteSession');
  }
}
