import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
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

    // No floating action button: it sat over the last rows of a long kit. The
    // same action now lives in the page, under the summary.
    return Scaffold(
      appBar: const FaceTuneTopBar(title: 'My Makeup Kit'),
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
          // Was `SizedBox(height: 120)` used as vertical centring, which put the
          // message at a different height here than on every other screen.
          const SizedBox(height: AppSpacing.xxl),
          StatusState.error(
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
    final productCount = state.items.length;
    final populatedCategoryCount = categories
        .where((category) => state.byCategory(category).isNotEmpty)
        .length;
    final textTheme = Theme.of(context).textTheme;

    // The app bar already says "My Makeup Kit"; the page no longer repeats it
    // as a headline. It opens on what is in the kit instead.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (!isEmpty) ...[
          Text(
            '$productCount product${productCount == 1 ? '' : 's'} · '
            '$populatedCategoryCount '
            'categor${populatedCategoryCount == 1 ? 'y' : 'ies'}',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Products you own and can use for My Makeup Kit looks. '
            'Incomplete kits are welcome.',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.muted(context),
            ),
          ),
        ],
        if (isGuest) ...[
          if (!isEmpty) const SizedBox(height: AppSpacing.md),
          // A temporary account whose data can vanish is a caution, not a hint.
          const AppNotice(
            tone: AppTone.warning,
            message:
                'Guest kits are private to this temporary account and may be '
                'lost after signing out or clearing app data.',
          ),
        ],
        if (isEmpty) ...[
          if (isGuest) const SizedBox(height: AppSpacing.lg),
          // A new kit is empty by definition. Nothing has gone wrong, so this
          // stays neutral and does not announce itself.
          StatusState.empty(
            title: 'No products yet',
            message:
                'Add the makeup you already own so FaceTune can use it for '
                'your My Makeup Kit looks.',
            icon: Icons.inventory_2_outlined,
            actionLabel: 'Add your first product',
            onAction: () => context.push(AppConstants.makeupKitAddProductRoute),
          ),
        ] else ...[
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: 'Add product',
            icon: Icons.add_rounded,
            onPressed: () =>
                context.push(AppConstants.makeupKitAddProductRoute),
          ),
          for (final category in categories) ...[
            const SizedBox(height: AppSpacing.lg),
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
        // Clears the last row from the system navigation area; nothing floats
        // over the list any more, so no extra allowance is needed.
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}
