import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../domain/entities/makeup_kit_category.dart';
import '../../domain/entities/makeup_kit_product.dart';
import '../controllers/makeup_kit_products_controller.dart';
import '../controllers/makeup_kit_products_state.dart';
import '../utils/makeup_kit_display.dart';
import '../widgets/makeup_kit_color_swatch.dart';
import 'add_makeup_kit_product_page.dart';

class MakeupKitProductPage extends ConsumerWidget {
  const MakeupKitProductPage({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(makeupKitProductsControllerProvider);
    final product = _findProduct(state.items);

    ref.listen<MakeupKitProductsState>(makeupKitProductsControllerProvider, (
      previous,
      next,
    ) {
      if (next.feedback == null || next.feedback == previous?.feedback) return;
      final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(next.feedback!),
          backgroundColor: next.feedbackIsError ? AppColors.error : null,
          action: next.sessionExpired
              ? SnackBarAction(
                  label: 'Sign in again',
                  onPressed: () => ref
                      .read(authControllerProvider.notifier)
                      .recoverExpiredSession(),
                )
              : null,
        ),
      );
      ref.read(makeupKitProductsControllerProvider.notifier).clearFeedback();
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Product Details')),
      body: SafeArea(
        child: PageFrame(
          child: product == null
              ? _missingContent(context, state)
              : _productContent(context, ref, product, state),
        ),
      ),
    );
  }

  MakeupKitProduct? _findProduct(List<MakeupKitProduct> items) {
    for (final product in items) {
      if (product.id == productId) return product;
    }
    return null;
  }

  Widget _missingContent(BuildContext context, MakeupKitProductsState state) {
    if (state.status == MakeupKitProductsStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: StatusState(
        title: 'Product unavailable',
        message: state.status == MakeupKitProductsStatus.failure
            ? state.message ?? 'Your makeup kit could not be loaded.'
            : 'This product is no longer in your makeup kit.',
        icon: Icons.inventory_2_outlined,
        actionLabel: 'Back to My Makeup Kit',
        onAction: context.pop,
      ),
    );
  }

  Widget _productContent(
    BuildContext context,
    WidgetRef ref,
    MakeupKitProduct product,
    MakeupKitProductsState state,
  ) {
    final isMutating = state.mutatingIds.contains(product.id);
    final isFoundation = product.category == MakeupKitCategory.foundation;
    return ListView(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MakeupKitColorSwatch(color: product.color),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      product.productName ??
                          product.colorLabel ??
                          product.category.label,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _Detail(label: 'Category', value: product.category.label),
              _Detail(
                label: 'Color',
                value: product.colorLabel == null
                    ? product.color.value
                    : '${product.colorLabel} (${product.color.value})',
              ),
              _Detail(label: 'Finish', value: product.finish.label),
              if (isFoundation && product.foundationDepth != null)
                _Detail(label: 'Depth', value: product.foundationDepth!.label),
              if (isFoundation && product.foundationUndertone != null)
                _Detail(
                  label: 'Undertone',
                  value: product.foundationUndertone!.label,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Edit Product',
          icon: Icons.edit_outlined,
          onPressed: isMutating
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddMakeupKitProductPage(product: product),
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
          onPressed: isMutating
              ? null
              : () => _confirmDelete(context, ref, product),
          icon: const Icon(Icons.delete_outline),
          label: Text(isMutating ? 'Deleting...' : 'Delete Product'),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MakeupKitProduct product,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete product?'),
        content: const Text(
          'This removes the product from your makeup kit. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onAccent(AppColors.error),
            ),
            onPressed: () => dialogContext.pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final succeeded = await ref
        .read(makeupKitProductsControllerProvider.notifier)
        .deleteProduct(product.id);
    if (succeeded && context.mounted) context.pop();
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
