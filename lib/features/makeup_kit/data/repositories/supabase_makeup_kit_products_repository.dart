import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/makeup_kit_category.dart';
import '../../domain/entities/makeup_kit_product.dart';
import '../../domain/errors/makeup_kit_failure.dart';
import '../../domain/repositories/makeup_kit_products_repository.dart';
import '../../domain/validation/makeup_kit_product_validator.dart';
import '../data_sources/makeup_kit_products_remote_data_source.dart';
import '../models/makeup_kit_product_dto.dart';

class SupabaseMakeupKitProductsRepository
    implements MakeupKitProductsRepository {
  const SupabaseMakeupKitProductsRepository(
    this._remote, {
    this.operationTimeout = const Duration(seconds: 20),
  });

  final MakeupKitProductsRemoteDataSource _remote;
  final Duration operationTimeout;

  @override
  Future<List<MakeupKitProduct>> loadAll() async {
    final userId = _requireSession();
    try {
      final rows = await _remote.selectAll().timeout(operationTimeout);
      return _mapRows(rows, userId);
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<List<MakeupKitProduct>> loadByCategory(
    MakeupKitCategory category,
  ) async {
    final userId = _requireSession();
    try {
      final rows = await _remote
          .selectByCategory(category.code)
          .timeout(operationTimeout);
      return _mapRows(rows, userId);
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<MakeupKitProduct> create(MakeupKitProductDraft draft) async {
    MakeupKitProductValidator.validate(draft);
    final userId = _requireSession();
    try {
      final row = await _remote
          .insert(MakeupKitProductDto.toInsertRow(userId: userId, draft: draft))
          .timeout(operationTimeout);
      return _ownedProduct(row, userId);
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<MakeupKitProduct> update(
    String productId,
    MakeupKitProductDraft draft,
  ) async {
    MakeupKitProductValidator.validate(draft);
    final userId = _requireSession();
    try {
      final row = await _remote
          .update(productId, MakeupKitProductDto.toUpdateRow(draft))
          .timeout(operationTimeout);
      return _ownedProduct(row, userId);
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<void> delete(String productId) async {
    _requireSession();
    try {
      await _remote.delete(productId).timeout(operationTimeout);
    } catch (error) {
      throw _failure(error);
    }
  }

  List<MakeupKitProduct> _mapRows(
    List<Map<String, Object?>> rows,
    String userId,
  ) => List.unmodifiable(rows.map((row) => _ownedProduct(row, userId)));

  MakeupKitProduct _ownedProduct(Map<String, Object?> row, String userId) {
    final product = MakeupKitProductDto.fromRow(row);
    if (product.userId != userId) {
      throw const FormatException('Product ownership is invalid.');
    }
    return product;
  }

  String _requireSession() {
    final userId = _remote.currentUserId;
    if (userId == null) {
      throw const MakeupKitFailure(
        'Your session expired. Sign in again.',
        kind: MakeupKitFailureKind.sessionExpired,
        retryable: false,
      );
    }
    return userId;
  }

  static MakeupKitFailure _failure(Object error) {
    if (error is MakeupKitFailure) return error;
    if (error is SocketException || error is TimeoutException) {
      return MakeupKitFailure(
        error is TimeoutException
            ? 'That request is taking too long. Please try again.'
            : 'Check your connection and try again.',
        kind: error is TimeoutException
            ? MakeupKitFailureKind.timeout
            : MakeupKitFailureKind.offline,
      );
    }
    if (error is AuthException) {
      return const MakeupKitFailure(
        'Your session expired. Sign in again.',
        kind: MakeupKitFailureKind.sessionExpired,
        retryable: false,
      );
    }
    if (error is PostgrestException && _isExpiredSession(error)) {
      return const MakeupKitFailure(
        'Your session expired. Sign in again.',
        kind: MakeupKitFailureKind.sessionExpired,
        retryable: false,
      );
    }
    if (error is PostgrestException && error.code == 'PGRST116') {
      return const MakeupKitFailure(
        'That product no longer exists in your kit.',
        kind: MakeupKitFailureKind.notFound,
        retryable: false,
      );
    }
    if (error is PostgrestException) {
      return const MakeupKitFailure(
        'Your makeup kit could not be updated right now.',
        kind: MakeupKitFailureKind.unavailable,
      );
    }
    if (error is FormatException) {
      return const MakeupKitFailure(
        'A product in your kit contains invalid data.',
        kind: MakeupKitFailureKind.validation,
        retryable: false,
      );
    }
    return const MakeupKitFailure(
      'Your makeup kit could not be loaded.',
      kind: MakeupKitFailureKind.unknown,
    );
  }

  static bool _isExpiredSession(PostgrestException error) {
    final detail = '${error.code} ${error.message} ${error.details}'
        .toLowerCase();
    return error.code == 'PGRST301' ||
        (detail.contains('jwt') &&
            (detail.contains('expired') || detail.contains('invalid')));
  }
}
