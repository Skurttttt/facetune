import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../data/providers/makeup_kit_products_providers.dart';
import '../../domain/entities/makeup_kit_product.dart';
import '../../domain/errors/makeup_kit_failure.dart';
import '../../domain/repositories/makeup_kit_products_repository.dart';
import 'makeup_kit_products_state.dart';

final makeupKitProductsControllerProvider =
    StateNotifierProvider<MakeupKitProductsController, MakeupKitProductsState>((
      ref,
    ) {
      ref.watch(makeupKitProductsRevisionProvider);
      ref.watch(authControllerProvider.select((state) => state.user?.id));
      final controller = MakeupKitProductsController(
        ref.watch(makeupKitProductsRepositoryProvider),
      );
      controller.load();
      return controller;
    });

class MakeupKitProductsController
    extends StateNotifier<MakeupKitProductsState> {
  MakeupKitProductsController(this._repository)
    : super(const MakeupKitProductsState());

  static const _operationTimeout = Duration(seconds: 20);
  final MakeupKitProductsRepository _repository;
  int _loadGeneration = 0;

  Future<void> load() async {
    final generation = ++_loadGeneration;
    state = const MakeupKitProductsState();
    try {
      final items = await _repository.loadAll().timeout(_operationTimeout);
      if (!mounted || generation != _loadGeneration) return;
      state = MakeupKitProductsState(
        status: MakeupKitProductsStatus.ready,
        items: items,
      );
    } on MakeupKitFailure catch (failure) {
      if (!mounted || generation != _loadGeneration) return;
      state = MakeupKitProductsState(
        status: MakeupKitProductsStatus.failure,
        message: failure.message,
        sessionExpired: failure.kind == MakeupKitFailureKind.sessionExpired,
      );
    } on TimeoutException {
      if (!mounted || generation != _loadGeneration) return;
      state = const MakeupKitProductsState(
        status: MakeupKitProductsStatus.failure,
        message:
            'Loading your makeup kit took too long. Check your connection.',
      );
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      state = const MakeupKitProductsState(
        status: MakeupKitProductsStatus.failure,
        message: 'Your makeup kit could not be loaded right now.',
      );
    }
  }

  Future<void> refresh() => load();

  /// Returns whether the product was created.
  ///
  /// Callers that need to react to the outcome (e.g. popping a form screen)
  /// must use this return value rather than inspecting [state] after the
  /// `await`: a `ref.listen` elsewhere (showing/clearing the feedback
  /// SnackBar) reacts to the same state change synchronously and can reset
  /// `feedbackIsError` back to `false` before the caller's continuation
  /// resumes, making a post-await state read unreliable.
  Future<bool> createProduct(MakeupKitProductDraft draft) async {
    if (state.isCreating) return false;
    state = _state(isCreating: true);
    try {
      final created = await _repository
          .create(draft)
          .timeout(_operationTimeout);
      if (!mounted) return false;
      state = _state(
        status: MakeupKitProductsStatus.ready,
        items: List.unmodifiable([...state.items, created]),
        isCreating: false,
        feedback: 'Product added to your kit.',
        sessionExpired: false,
      );
      return true;
    } on MakeupKitFailure catch (failure) {
      _createFailed(
        failure.message,
        sessionExpired: failure.kind == MakeupKitFailureKind.sessionExpired,
      );
      return false;
    } on TimeoutException {
      _createFailed('Adding the product took too long. Check your connection.');
      return false;
    } catch (_) {
      _createFailed('The product could not be added right now.');
      return false;
    }
  }

  void _createFailed(String message, {bool sessionExpired = false}) {
    if (!mounted) return;
    state = _state(
      isCreating: false,
      feedback: message,
      feedbackIsError: true,
      sessionExpired: sessionExpired,
    );
  }

  /// Returns whether the product was updated — see [createProduct] for why
  /// callers must use this instead of inspecting [state] after the `await`.
  Future<bool> updateProduct(
    String productId,
    MakeupKitProductDraft draft,
  ) async {
    if (state.mutatingIds.contains(productId)) return false;
    state = _state(mutatingIds: {...state.mutatingIds, productId});
    try {
      final updated = await _repository
          .update(productId, draft)
          .timeout(_operationTimeout);
      if (!mounted) return false;
      state = _state(
        status: MakeupKitProductsStatus.ready,
        items: List.unmodifiable([
          for (final item in state.items)
            if (item.id == productId) updated else item,
        ]),
        mutatingIds: {...state.mutatingIds}..remove(productId),
        feedback: 'Product updated.',
        sessionExpired: false,
      );
      return true;
    } on MakeupKitFailure catch (failure) {
      _mutationFailed(
        productId,
        failure.message,
        sessionExpired: failure.kind == MakeupKitFailureKind.sessionExpired,
      );
      return false;
    } on TimeoutException {
      _mutationFailed(
        productId,
        'Updating the product took too long. Check your connection.',
      );
      return false;
    } catch (_) {
      _mutationFailed(productId, 'The product could not be updated right now.');
      return false;
    }
  }

  /// Returns whether the product was deleted — see [createProduct] for why
  /// callers must use this instead of inspecting [state] after the `await`.
  Future<bool> deleteProduct(String productId) async {
    if (state.mutatingIds.contains(productId)) return false;
    state = _state(mutatingIds: {...state.mutatingIds, productId});
    try {
      await _repository.delete(productId).timeout(_operationTimeout);
      if (!mounted) return false;
      state = _state(
        status: MakeupKitProductsStatus.ready,
        items: List.unmodifiable(
          state.items.where((item) => item.id != productId),
        ),
        mutatingIds: {...state.mutatingIds}..remove(productId),
        feedback: 'Product removed from your kit.',
        sessionExpired: false,
      );
      return true;
    } on MakeupKitFailure catch (failure) {
      _mutationFailed(
        productId,
        failure.message,
        sessionExpired: failure.kind == MakeupKitFailureKind.sessionExpired,
      );
      return false;
    } on TimeoutException {
      _mutationFailed(
        productId,
        'Removing the product took too long. Check your connection.',
      );
      return false;
    } catch (_) {
      _mutationFailed(productId, 'The product could not be removed right now.');
      return false;
    }
  }

  void _mutationFailed(
    String productId,
    String message, {
    bool sessionExpired = false,
  }) {
    if (!mounted) return;
    state = _state(
      mutatingIds: {...state.mutatingIds}..remove(productId),
      feedback: message,
      feedbackIsError: true,
      sessionExpired: sessionExpired,
    );
  }

  void clearFeedback() => state = _state();

  MakeupKitProductsState _state({
    MakeupKitProductsStatus? status,
    List<MakeupKitProduct>? items,
    bool? isCreating,
    Set<String>? mutatingIds,
    String? feedback,
    bool feedbackIsError = false,
    bool? sessionExpired,
  }) => MakeupKitProductsState(
    status: status ?? state.status,
    items: items ?? state.items,
    isCreating: isCreating ?? state.isCreating,
    mutatingIds: Set.unmodifiable(mutatingIds ?? state.mutatingIds),
    message: state.message,
    feedback: feedback,
    feedbackIsError: feedbackIsError,
    sessionExpired: sessionExpired ?? state.sessionExpired,
  );
}
