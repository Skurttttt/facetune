import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../domain/entities/makeup_kit_category.dart';
import '../../domain/entities/makeup_kit_product.dart';
import '../../domain/value_objects/normalized_hex_color.dart';
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
      // The shared snackbar, as the add/edit form already uses for the same
      // controller feedback: a failed delete and a failed save now look
      // alike, and the danger tone is readable in both themes (the raw
      // `AppColors.error` ground used here before was not theme-aware).
      showAppSnackBar(
        context,
        message: next.feedback!,
        tone: next.feedbackIsError ? AppTone.danger : AppTone.success,
        actionLabel: next.sessionExpired ? 'Sign in again' : null,
        onAction: next.sessionExpired
            ? () => ref
                  .read(authControllerProvider.notifier)
                  .recoverExpiredSession()
            : null,
      );
      ref.read(makeupKitProductsControllerProvider.notifier).clearFeedback();
    });

    return Scaffold(
      appBar: const FaceTuneTopBar(title: 'Product Details'),
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
      return const Center(child: LoadingState(label: 'Loading this product…'));
    }
    return Center(
      child: StatusState.error(
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
    final textTheme = Theme.of(context).textTheme;
    // The same title source as before. When it falls back to the category,
    // the category line under it would only repeat it.
    final title =
        product.productName ?? product.colorLabel ?? product.category.label;
    final showsCategoryUnderTitle = title != product.category.label;

    return ListView(
      children: [
        // Identity: what this product is, before the attributes.
        Row(
          children: [
            // Decorative here; the Color row below names it.
            ExcludeSemantics(
              child: MakeupKitColorSwatch(
                color: product.color,
                size: AppIconSizes.hero,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(title, style: textTheme.titleLarge),
                  ),
                  if (showsCategoryUnderTitle)
                    Text(
                      product.category.label,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted(context),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailItem(label: 'Category', value: product.category.label),
              _DetailItem(
                label: 'Color',
                value: product.colorLabel ?? product.color.value,
                secondaryValue: product.colorLabel == null
                    ? null
                    : product.color.value,
                swatch: product.color,
              ),
              _DetailItem(label: 'Finish', value: product.finish.label),
              if (isFoundation && product.foundationDepth != null)
                _DetailItem(
                  label: 'Depth',
                  value: product.foundationDepth!.label,
                ),
              if (isFoundation && product.foundationUndertone != null)
                _DetailItem(
                  label: 'Undertone',
                  value: product.foundationUndertone!.label,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Edit product',
          icon: Icons.edit_outlined,
          onPressed: isMutating
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddMakeupKitProductPage(product: product),
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // Destructive and rare, so a text action rather than a second
        // full-weight button. The confirmation dialog is unchanged.
        Center(
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppTone.danger.resolve(context).accent,
            ),
            onPressed: isMutating
                ? null
                : () => _confirmDelete(context, ref, product),
            icon: const Icon(Icons.delete_outline),
            label: Text(isMutating ? 'Deleting…' : 'Delete product'),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MakeupKitProduct product,
  ) async {
    // The shared destructive confirmation. Same title, same warning, same
    // outcome — but the danger styling and the "Delete" label now come from one
    // place, so every irreversible action in the app looks alike.
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Delete product?',
      message:
          'This removes the product from your makeup kit. This action cannot '
          'be undone.',
      isDestructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    final succeeded = await ref
        .read(makeupKitProductsControllerProvider.notifier)
        .deleteProduct(product.id);
    if (succeeded && context.mounted) context.pop();
  }
}

/// One product attribute: a small label above its value.
///
/// Stacked rather than [DetailRow]'s columns so a value never competes with a
/// label column for width, at any text size, and so the Color value can carry
/// its swatch. Read as one phrase by assistive technology ("Color, Warm
/// Beige, #C99578").
class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.label,
    required this.value,
    this.secondaryValue,
    this.swatch,
  });

  final String label;
  final String value;
  final String? secondaryValue;
  final NormalizedHexColor? swatch;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = AppColors.muted(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: textTheme.labelMedium?.copyWith(color: muted)),
            const SizedBox(height: AppSpacing.xxs),
            Row(
              children: [
                if (swatch != null) ...[
                  ExcludeSemantics(
                    child: MakeupKitColorSwatch(
                      color: swatch!,
                      size: AppIconSizes.md,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value, style: textTheme.bodyLarge),
                      if (secondaryValue != null)
                        Text(
                          secondaryValue!,
                          style: textTheme.bodySmall?.copyWith(color: muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
