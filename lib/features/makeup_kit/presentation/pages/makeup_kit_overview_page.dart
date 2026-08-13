import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../domain/entities/makeup_kit_category.dart';
import '../controllers/makeup_kit_products_controller.dart';
import '../controllers/makeup_kit_products_state.dart';
import '../widgets/makeup_kit_category_section.dart';

class MakeupKitOverviewPage extends ConsumerWidget {
  const MakeupKitOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(makeupKitProductsControllerProvider);
    final isGuest = ref.watch(authControllerProvider).user?.isAnonymous == true;

    return Scaffold(
      appBar: AppBar(title: const Text('My Makeup Kit')),
      floatingActionButton: state.status == MakeupKitProductsStatus.ready
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.push(AppConstants.makeupKitAddProductRoute),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Product'),
            )
          : null,
      body: SafeArea(
        child: PageFrame(
          child: RefreshIndicator(
            onRefresh: () => ref
                .read(makeupKitProductsControllerProvider.notifier)
                .refresh(),
            child: _buildContent(context, ref, state, isGuest),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    MakeupKitProductsState state,
    bool isGuest,
  ) {
    if (state.status == MakeupKitProductsStatus.loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: AppSpacing.md),
          SkeletonCard(imageHeight: 0),
          SizedBox(height: AppSpacing.sm),
          SkeletonCard(imageHeight: 0),
          SizedBox(height: AppSpacing.sm),
          SkeletonCard(imageHeight: 0),
        ],
      );
    }

    if (state.status == MakeupKitProductsStatus.failure) {
      final sessionExpired = state.sessionExpired;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          StatusState(
            title: 'My Makeup Kit unavailable',
            message: state.message ?? 'Please try again.',
            icon: Icons.cloud_off_outlined,
            actionLabel: sessionExpired ? 'Sign in again' : 'Try again',
            onAction: sessionExpired
                ? () => ref
                      .read(authControllerProvider.notifier)
                      .recoverExpiredSession()
                : () => ref
                      .read(makeupKitProductsControllerProvider.notifier)
                      .load(),
          ),
        ],
      );
    }

    final isEmpty = state.items.isEmpty;
    final categories = MakeupKitCategory.values;
    final populatedCategoryCount = categories
        .where((category) => state.byCategory(category).isNotEmpty)
        .length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Text(
          'My Makeup Kit',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text('Products you already own, organized by category.'),
        if (isGuest) ...[
          const SizedBox(height: AppSpacing.md),
          const AppCard(
            color: AppColors.petal,
            child: Text(
              'Guest kits are private to this temporary account and may be lost after signing out or clearing app data.',
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (isEmpty)
          StatusState(
            title: 'Your kit is empty',
            message:
                'Add the makeup products you own to build personalized looks from them.',
            icon: Icons.inventory_2_outlined,
            actionLabel: 'Add Product',
            onAction: () => context.push(AppConstants.makeupKitAddProductRoute),
          )
        else ...[
          AppCard(
            color: AppColors.petal,
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.rose),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${state.items.length} product${state.items.length == 1 ? '' : 's'} across '
                    '$populatedCategoryCount '
                    'categor${populatedCategoryCount == 1 ? 'y' : 'ies'}. '
                    'Incomplete kits are welcome.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                for (final category in categories) ...[
                  if (category != categories.first) const Divider(height: 1),
                  MakeupKitCategorySection(
                    category: category,
                    products: state.byCategory(category),
                    onProductTap: (product) => context.pushNamed(
                      'makeupKitProduct',
                      pathParameters: {'productId': product.id},
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}
