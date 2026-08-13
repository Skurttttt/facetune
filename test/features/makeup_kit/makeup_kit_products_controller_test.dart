import 'dart:async';

import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_finish.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_product.dart';
import 'package:facetune/features/makeup_kit/domain/errors/makeup_kit_failure.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_products_repository.dart';
import 'package:facetune/features/makeup_kit/domain/value_objects/normalized_hex_color.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_products_controller.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_products_state.dart';
import 'package:flutter_test/flutter_test.dart';

MakeupKitProduct _product(
  String id, {
  MakeupKitCategory category = MakeupKitCategory.lipstick,
  MakeupKitFinish finish = MakeupKitFinish.matte,
}) => MakeupKitProduct(
  id: id,
  userId: 'user-1',
  category: category,
  color: NormalizedHexColor.parse('#B86F72'),
  finish: finish,
  createdAt: DateTime.utc(2026, 8, 13),
  updatedAt: DateTime.utc(2026, 8, 13),
);

MakeupKitProductDraft _draft() => MakeupKitProductDraft(
  category: MakeupKitCategory.lipstick,
  color: NormalizedHexColor.parse('#B86F72'),
  finish: MakeupKitFinish.matte,
);

void main() {
  group('load', () {
    test('loads the full kit', () async {
      final repository = _FakeRepository(items: [_product('a'), _product('b')]);
      final controller = MakeupKitProductsController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.status, MakeupKitProductsStatus.ready);
      expect(controller.state.items.map((p) => p.id), ['a', 'b']);
    });

    test('reports a friendly load failure', () async {
      final repository = _FakeRepository(
        loadError: const MakeupKitFailure(
          'Your makeup kit could not be loaded.',
        ),
      );
      final controller = MakeupKitProductsController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.status, MakeupKitProductsStatus.failure);
      expect(controller.state.message, 'Your makeup kit could not be loaded.');
    });

    test('a stale load cannot overwrite a newer refresh', () async {
      final first = Completer<List<MakeupKitProduct>>();
      final repository = _FakeRepository(pendingLoad: first);
      final controller = MakeupKitProductsController(repository);
      addTearDown(controller.dispose);

      final stale = controller.load();
      repository.pendingLoad = null;
      repository.items = [_product('fresh')];
      final fresh = controller.load();
      first.complete([_product('stale')]);
      await Future.wait([stale, fresh]);

      expect(controller.state.items.map((p) => p.id), ['fresh']);
    });

    test('byCategory filters the loaded items', () async {
      final repository = _FakeRepository(
        items: [
          _product('a', category: MakeupKitCategory.lipstick),
          _product('b', category: MakeupKitCategory.blush),
        ],
      );
      final controller = MakeupKitProductsController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      expect(
        controller.state.byCategory(MakeupKitCategory.blush).map((p) => p.id),
        ['b'],
      );
    });
  });

  group('createProduct', () {
    test('appends the created product on success', () async {
      final repository = _FakeRepository(createResult: _product('new'));
      final controller = MakeupKitProductsController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      await controller.createProduct(_draft());

      expect(controller.state.items.map((p) => p.id), ['new']);
      expect(controller.state.isCreating, isFalse);
      expect(controller.state.feedback, 'Product added to your kit.');
      expect(controller.state.feedbackIsError, isFalse);
    });

    test('reports feedback and clears isCreating on failure', () async {
      final repository = _FakeRepository(
        createError: const MakeupKitFailure('Could not add product.'),
      );
      final controller = MakeupKitProductsController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      await controller.createProduct(_draft());

      expect(controller.state.items, isEmpty);
      expect(controller.state.isCreating, isFalse);
      expect(controller.state.feedback, 'Could not add product.');
      expect(controller.state.feedbackIsError, isTrue);
    });

    test('ignores a second create while one is in flight', () async {
      final completer = Completer<MakeupKitProduct>();
      final repository = _FakeRepository(pendingCreate: completer);
      final controller = MakeupKitProductsController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      final first = controller.createProduct(_draft());
      final second = controller.createProduct(_draft());
      expect(repository.createCalls, 1);

      completer.complete(_product('new'));
      await Future.wait([first, second]);
      expect(controller.state.items, hasLength(1));
    });
  });

  group('updateProduct', () {
    test('replaces the updated product in place', () async {
      final repository = _FakeRepository(
        items: [_product('a')],
        updateResult: _product('a', category: MakeupKitCategory.blush),
      );
      final controller = MakeupKitProductsController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      await controller.updateProduct('a', _draft());

      expect(controller.state.items.single.category, MakeupKitCategory.blush);
      expect(controller.state.mutatingIds, isNot(contains('a')));
      expect(controller.state.feedback, 'Product updated.');
    });

    test('reports feedback on update failure and clears mutatingIds', () async {
      final repository = _FakeRepository(
        items: [_product('a')],
        updateError: const MakeupKitFailure('Could not update product.'),
      );
      final controller = MakeupKitProductsController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      await controller.updateProduct('a', _draft());

      expect(controller.state.items.single.id, 'a');
      expect(controller.state.mutatingIds, isNot(contains('a')));
      expect(controller.state.feedback, 'Could not update product.');
      expect(controller.state.feedbackIsError, isTrue);
    });
  });

  group('deleteProduct', () {
    test('removes the deleted product', () async {
      final repository = _FakeRepository(items: [_product('a'), _product('b')]);
      final controller = MakeupKitProductsController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      await controller.deleteProduct('a');

      expect(controller.state.items.map((p) => p.id), ['b']);
      expect(controller.state.feedback, 'Product removed from your kit.');
    });

    test('duplicate delete taps are ignored while mutating', () async {
      final completer = Completer<void>();
      final repository = _FakeRepository(
        items: [_product('a')],
        pendingDelete: completer,
      );
      final controller = MakeupKitProductsController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      final first = controller.deleteProduct('a');
      final second = controller.deleteProduct('a');
      expect(repository.deleteCalls, 1);
      expect(controller.state.mutatingIds, contains('a'));

      completer.complete();
      await Future.wait([first, second]);
      expect(controller.state.mutatingIds, isNot(contains('a')));
      expect(controller.state.items, isEmpty);
    });

    test('session expiry is surfaced on the state', () async {
      final repository = _FakeRepository(
        items: [_product('a')],
        deleteError: const MakeupKitFailure(
          'Your session expired. Sign in again.',
          kind: MakeupKitFailureKind.sessionExpired,
          retryable: false,
        ),
      );
      final controller = MakeupKitProductsController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      await controller.deleteProduct('a');

      expect(controller.state.sessionExpired, isTrue);
    });
  });
}

class _FakeRepository implements MakeupKitProductsRepository {
  _FakeRepository({
    List<MakeupKitProduct> items = const [],
    this.loadError,
    this.createResult,
    this.createError,
    this.updateResult,
    this.updateError,
    this.deleteError,
    this.pendingLoad,
    this.pendingCreate,
    this.pendingDelete,
  }) : items = List.of(items);

  List<MakeupKitProduct> items;
  Object? loadError;
  MakeupKitProduct? createResult;
  Object? createError;
  MakeupKitProduct? updateResult;
  Object? updateError;
  Object? deleteError;
  Completer<List<MakeupKitProduct>>? pendingLoad;
  Completer<MakeupKitProduct>? pendingCreate;
  Completer<void>? pendingDelete;
  int createCalls = 0;
  int deleteCalls = 0;

  @override
  Future<List<MakeupKitProduct>> loadAll() async {
    if (pendingLoad != null) return pendingLoad!.future;
    if (loadError != null) throw loadError!;
    return items;
  }

  @override
  Future<List<MakeupKitProduct>> loadByCategory(
    MakeupKitCategory category,
  ) async => items.where((item) => item.category == category).toList();

  @override
  Future<MakeupKitProduct> create(MakeupKitProductDraft draft) async {
    createCalls++;
    if (pendingCreate != null) return pendingCreate!.future;
    if (createError != null) throw createError!;
    return createResult!;
  }

  @override
  Future<MakeupKitProduct> update(
    String productId,
    MakeupKitProductDraft draft,
  ) async {
    if (updateError != null) throw updateError!;
    return updateResult!;
  }

  @override
  Future<void> delete(String productId) async {
    deleteCalls++;
    if (pendingDelete != null) return pendingDelete!.future;
    if (deleteError != null) throw deleteError!;
  }
}
