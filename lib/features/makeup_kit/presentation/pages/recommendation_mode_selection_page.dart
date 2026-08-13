import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../../analysis/presentation/controllers/face_analysis_controller.dart';
import '../../../makeup_styles/presentation/controllers/makeup_style_selection_controller.dart';
import '../../../recommendation/presentation/controllers/makeup_recommendation_controller.dart';
import '../../domain/entities/makeup_recommendation_mode.dart';
import '../controllers/makeup_kit_products_controller.dart';
import '../controllers/makeup_kit_products_state.dart';
import '../controllers/makeup_recommendation_mode_controller.dart';

class RecommendationModeSelectionPage extends ConsumerWidget {
  const RecommendationModeSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(faceAnalysisControllerProvider).analysis;
    final style = ref
        .watch(makeupStyleSelectionControllerProvider)
        .selectedStyle;
    final kit = ref.watch(makeupKitProductsControllerProvider);

    if (analysis == null || style == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Choose recommendation mode')),
        body: SafeArea(
          child: PageFrame(
            child: Center(
              child: StatusState(
                title: 'Your scan is not ready',
                message:
                    'Complete your analysis and choose a makeup style first.',
                icon: Icons.info_outline_rounded,
                actionLabel: analysis == null
                    ? 'Return to analysis'
                    : 'Choose a style',
                onAction: () => context.go(
                  analysis == null
                      ? AppConstants.analysisRoute
                      : AppConstants.stylesRoute,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Choose recommendation mode')),
      body: SafeArea(
        child: PageFrame(
          child: ListView(
            children: [
              Text(
                'How would you like to create your look?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${style.name} is selected. Choose one recommendation strategy.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted(context),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ModeCard(
                title: 'Makeup Recommendation',
                description: 'Let FaceTune choose the ideal makeup for you.',
                icon: Icons.auto_awesome_rounded,
                actionLabel: 'Use Makeup Recommendation',
                onPressed: () => _startStandard(context, ref),
              ),
              const SizedBox(height: AppSpacing.md),
              _kitCard(context, ref, kit),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kitCard(
    BuildContext context,
    WidgetRef ref,
    MakeupKitProductsState kit,
  ) {
    final isReady = kit.status == MakeupKitProductsStatus.ready;
    final hasProducts = isReady && kit.items.isNotEmpty;
    return _ModeCard(
      title: 'My Makeup Kit',
      description: hasProducts
          ? 'Create a look using ${kit.items.length} product${kit.items.length == 1 ? '' : 's'} you already own.'
          : isReady
          ? 'Add at least one product before creating a kit-based look.'
          : kit.status == MakeupKitProductsStatus.failure
          ? kit.message ?? 'Your makeup kit could not be checked.'
          : 'Checking your makeup kit…',
      icon: Icons.inventory_2_outlined,
      actionLabel: hasProducts
          ? 'Use My Makeup Kit'
          : isReady
          ? 'Add Product'
          : kit.status == MakeupKitProductsStatus.failure
          ? 'Try Again'
          : 'Checking Kit…',
      onPressed: hasProducts
          ? () {
              ref
                  .read(makeupRecommendationModeControllerProvider.notifier)
                  .select(MakeupRecommendationMode.makeupKit);
              context.push(AppConstants.makeupKitRecommendationEntryRoute);
            }
          : isReady
          ? () => context.push(AppConstants.makeupKitAddProductRoute)
          : kit.status == MakeupKitProductsStatus.failure
          ? () =>
                ref.read(makeupKitProductsControllerProvider.notifier).refresh()
          : null,
    );
  }

  void _startStandard(BuildContext context, WidgetRef ref) {
    final analysis = ref.read(faceAnalysisControllerProvider).analysis;
    final style = ref
        .read(makeupStyleSelectionControllerProvider)
        .selectedStyle;
    if (analysis == null || style == null) return;
    ref
        .read(makeupRecommendationModeControllerProvider.notifier)
        .select(MakeupRecommendationMode.standard);
    ref
        .read(makeupRecommendationControllerProvider.notifier)
        .generate(analysis: analysis, style: style);
    context.push(AppConstants.recommendationRoute);
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String description;
  final IconData icon;
  final String actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.rose, size: AppIconSizes.lg),
        const SizedBox(height: AppSpacing.sm),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(description),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: actionLabel,
          icon: Icons.arrow_forward_rounded,
          onPressed: onPressed,
        ),
      ],
    ),
  );
}
