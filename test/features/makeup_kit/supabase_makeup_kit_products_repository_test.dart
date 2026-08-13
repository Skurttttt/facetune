import 'dart:async';
import 'dart:io';

import 'package:facetune/features/makeup_kit/data/data_sources/makeup_kit_products_remote_data_source.dart';
import 'package:facetune/features/makeup_kit/data/repositories/supabase_makeup_kit_products_repository.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_finish.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_product.dart';
import 'package:facetune/features/makeup_kit/domain/errors/makeup_kit_failure.dart';
import 'package:facetune/features/makeup_kit/domain/value_objects/normalized_hex_color.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, Object?> _row({
  String id = 'product-1',
  String userId = 'user-1',
  String category = 'lipstick',
  Object? productName = 'My Nude Lipstick',
  String colorHex = '#B86F72',
  Object? colorLabel,
  String finish = 'matte',
  Object? foundationDepth,
  Object? foundationUndertone,
}) => {
  'id': id,
  'user_id': userId,
  'category': category,
  'product_name': productName,
  'color_hex': colorHex,
  'color_label': colorLabel,
  'finish': finish,
  'foundation_depth': foundationDepth,
  'foundation_undertone': foundationUndertone,
  'created_at': '2026-08-13T00:00:00Z',
  'updated_at': '2026-08-13T00:00:00Z',
};

MakeupKitProductDraft _draft({
  MakeupKitCategory category = MakeupKitCategory.lipstick,
  MakeupKitFinish finish = MakeupKitFinish.matte,
}) => MakeupKitProductDraft(
  category: category,
  color: NormalizedHexColor.parse('#B86F72'),
  finish: finish,
);

void main() {
  group('loadAll / loadByCategory', () {
    test('maps every returned row into a domain product', () async {
      final remote = _FakeRemoteDataSource(
        allRows: [
          _row(id: 'a'),
          _row(id: 'b', category: 'blush', finish: 'satin'),
        ],
      );
      final repository = SupabaseMakeupKitProductsRepository(remote);

      final products = await repository.loadAll();

      expect(products.map((p) => p.id), ['a', 'b']);
      expect(products[1].category, MakeupKitCategory.blush);
    });

    test('loadByCategory forwards the stable category code', () async {
      final remote = _FakeRemoteDataSource(byCategoryRows: [_row()]);
      final repository = SupabaseMakeupKitProductsRepository(remote);

      final products = await repository.loadByCategory(
        MakeupKitCategory.lipstick,
      );

      expect(remote.requestedCategoryCode, 'lipstick');
      expect(products, hasLength(1));
    });

    test('requires an active session before loading', () async {
      final remote = _FakeRemoteDataSource(currentUserId: null);
      final repository = SupabaseMakeupKitProductsRepository(remote);

      await expectLater(
        repository.loadAll(),
        throwsA(
          isA<MakeupKitFailure>().having(
            (f) => f.kind,
            'kind',
            MakeupKitFailureKind.sessionExpired,
          ),
        ),
      );
    });

    test('rejects a row owned by another account', () async {
      final remote = _FakeRemoteDataSource(
        allRows: [_row(userId: 'another-user')],
      );
      final repository = SupabaseMakeupKitProductsRepository(remote);

      await expectLater(
        repository.loadAll(),
        throwsA(
          isA<MakeupKitFailure>().having(
            (failure) => failure.kind,
            'kind',
            MakeupKitFailureKind.validation,
          ),
        ),
      );
    });
  });

  group('create', () {
    test('validates the draft before touching the data source', () async {
      final remote = _FakeRemoteDataSource();
      final repository = SupabaseMakeupKitProductsRepository(remote);

      await expectLater(
        repository.create(
          _draft(
            category: MakeupKitCategory.eyebrow,
            finish: MakeupKitFinish.glitter,
          ),
        ),
        throwsA(
          isA<MakeupKitFailure>().having(
            (f) => f.kind,
            'kind',
            MakeupKitFailureKind.validation,
          ),
        ),
      );
      expect(remote.insertedValues, isNull);
    });

    test('inserts a validated draft and returns the mapped product', () async {
      final remote = _FakeRemoteDataSource(insertResult: _row());
      final repository = SupabaseMakeupKitProductsRepository(remote);

      final created = await repository.create(_draft());

      expect(remote.insertedValues?['user_id'], 'user-1');
      expect(remote.insertedValues?['category'], 'lipstick');
      expect(created.id, 'product-1');
    });
  });

  group('update', () {
    test('updates the product identified by id', () async {
      final remote = _FakeRemoteDataSource(
        updateResult: _row(category: 'blush', finish: 'satin'),
      );
      final repository = SupabaseMakeupKitProductsRepository(remote);

      final updated = await repository.update(
        'product-1',
        _draft(
          category: MakeupKitCategory.blush,
          finish: MakeupKitFinish.satin,
        ),
      );

      expect(remote.updatedProductId, 'product-1');
      expect(updated.category, MakeupKitCategory.blush);
    });
  });

  group('delete', () {
    test('deletes the product identified by id', () async {
      final remote = _FakeRemoteDataSource();
      final repository = SupabaseMakeupKitProductsRepository(remote);

      await repository.delete('product-1');

      expect(remote.deletedProductId, 'product-1');
    });
  });

  group('backend failure mapping', () {
    test('maps a socket error to an offline failure', () async {
      final remote = _FakeRemoteDataSource(
        loadError: const SocketException('x'),
      );
      final repository = SupabaseMakeupKitProductsRepository(remote);

      await expectLater(
        repository.loadAll(),
        throwsA(
          isA<MakeupKitFailure>().having(
            (f) => f.kind,
            'kind',
            MakeupKitFailureKind.offline,
          ),
        ),
      );
    });

    test('maps a timeout to a timeout failure', () async {
      final remote = _FakeRemoteDataSource(loadError: TimeoutException('x'));
      final repository = SupabaseMakeupKitProductsRepository(remote);

      await expectLater(
        repository.loadAll(),
        throwsA(
          isA<MakeupKitFailure>().having(
            (f) => f.kind,
            'kind',
            MakeupKitFailureKind.timeout,
          ),
        ),
      );
    });

    test('maps an expired-session PostgrestException', () async {
      final remote = _FakeRemoteDataSource(
        loadError: const PostgrestException(
          message: 'jwt expired',
          code: 'PGRST301',
        ),
      );
      final repository = SupabaseMakeupKitProductsRepository(remote);

      await expectLater(
        repository.loadAll(),
        throwsA(
          isA<MakeupKitFailure>().having(
            (f) => f.kind,
            'kind',
            MakeupKitFailureKind.sessionExpired,
          ),
        ),
      );
    });

    test(
      'maps a not-found PostgrestException (e.g. deleted mid-flight)',
      () async {
        final remote = _FakeRemoteDataSource(
          updateResult: _row(),
          updateError: const PostgrestException(
            message: 'no rows',
            code: 'PGRST116',
          ),
        );
        final repository = SupabaseMakeupKitProductsRepository(remote);

        await expectLater(
          repository.update('product-1', _draft()),
          throwsA(
            isA<MakeupKitFailure>().having(
              (f) => f.kind,
              'kind',
              MakeupKitFailureKind.notFound,
            ),
          ),
        );
      },
    );

    test(
      'maps another PostgrestException to a generic unavailable failure',
      () async {
        final remote = _FakeRemoteDataSource(
          loadError: const PostgrestException(message: 'boom', code: '500'),
        );
        final repository = SupabaseMakeupKitProductsRepository(remote);

        await expectLater(
          repository.loadAll(),
          throwsA(
            isA<MakeupKitFailure>().having(
              (f) => f.kind,
              'kind',
              MakeupKitFailureKind.unavailable,
            ),
          ),
        );
      },
    );

    test('never exposes the raw PostgrestException to the caller', () async {
      final remote = _FakeRemoteDataSource(
        loadError: const PostgrestException(
          message: 'relation "public.makeup_kit_products" does not exist',
          code: '42P01',
        ),
      );
      final repository = SupabaseMakeupKitProductsRepository(remote);

      try {
        await repository.loadAll();
        fail('expected a MakeupKitFailure');
      } catch (error) {
        expect(error, isA<MakeupKitFailure>());
        expect(error.toString(), isNot(contains('42P01')));
        expect(error.toString(), isNot(contains('relation')));
      }
    });

    test(
      'maps a malformed row (FormatException) to a validation failure',
      () async {
        final remote = _FakeRemoteDataSource(allRows: [_row(colorHex: 'nope')]);
        final repository = SupabaseMakeupKitProductsRepository(remote);

        await expectLater(
          repository.loadAll(),
          throwsA(
            isA<MakeupKitFailure>().having(
              (f) => f.kind,
              'kind',
              MakeupKitFailureKind.validation,
            ),
          ),
        );
      },
    );
  });
}

class _FakeRemoteDataSource implements MakeupKitProductsRemoteDataSource {
  _FakeRemoteDataSource({
    String? currentUserId = 'user-1',
    List<Map<String, Object?>> allRows = const [],
    List<Map<String, Object?>> byCategoryRows = const [],
    Map<String, Object?>? insertResult,
    Map<String, Object?>? updateResult,
    Object? loadError,
    Object? updateError,
  }) : _currentUserId = currentUserId,
       _allRows = allRows,
       _byCategoryRows = byCategoryRows,
       _insertResult = insertResult,
       _updateResult = updateResult,
       _loadError = loadError,
       _updateError = updateError;

  final String? _currentUserId;
  final List<Map<String, Object?>> _allRows;
  final List<Map<String, Object?>> _byCategoryRows;
  final Map<String, Object?>? _insertResult;
  final Map<String, Object?>? _updateResult;
  final Object? _loadError;
  final Object? _updateError;

  String? requestedCategoryCode;
  Map<String, Object?>? insertedValues;
  String? updatedProductId;
  String? deletedProductId;

  @override
  String? get currentUserId => _currentUserId;

  @override
  Future<List<Map<String, Object?>>> selectAll() async {
    if (_loadError != null) throw _loadError;
    return _allRows;
  }

  @override
  Future<List<Map<String, Object?>>> selectByCategory(
    String categoryCode,
  ) async {
    requestedCategoryCode = categoryCode;
    if (_loadError != null) throw _loadError;
    return _byCategoryRows;
  }

  @override
  Future<Map<String, Object?>> insert(Map<String, Object?> values) async {
    insertedValues = values;
    return _insertResult ?? values;
  }

  @override
  Future<Map<String, Object?>> update(
    String productId,
    Map<String, Object?> values,
  ) async {
    updatedProductId = productId;
    if (_updateError != null) throw _updateError;
    return _updateResult ?? values;
  }

  @override
  Future<void> delete(String productId) async {
    deletedProductId = productId;
  }
}
