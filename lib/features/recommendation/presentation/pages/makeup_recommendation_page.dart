import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../controllers/makeup_recommendation_controller.dart';
import '../controllers/makeup_recommendation_state.dart';
import '../widgets/recommendation_item_card.dart';

class MakeupRecommendationPage extends ConsumerWidget {
  const MakeupRecommendationPage({super.key});

  static const _labels = {
    'foundation': 'Foundation',
    'concealer': 'Concealer',
    'contour': 'Contour',
    'highlight': 'Highlight',
    'blush': 'Blush',
    'eyeshadow': 'Eyeshadow',
    'eyebrow': 'Eyebrows',
    'eyeliner': 'Eyeliner',
    'lipstick': 'Lipstick',
    'lipGloss': 'Lip gloss',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(makeupRecommendationControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Your makeup plan')),
      body: SafeArea(
        child: PageFrame(
          child: switch (state.status) {
            MakeupRecommendationStatus.generating => const Center(
              child: LoadingState(
                label: 'Designing your personalized makeup plan…',
              ),
            ),
            MakeupRecommendationStatus.failure => Center(
              child: StatusState(
                title: 'We could not create your plan',
                message: state.message ?? 'Please try again.',
                icon: Icons.error_outline_rounded,
                actionLabel: state.retryable ? 'Try again' : null,
                onAction: state.retryable
                    ? () => ref
                          .read(makeupRecommendationControllerProvider.notifier)
                          .retry()
                    : null,
              ),
            ),
            MakeupRecommendationStatus.success => _RecommendationContent(
              state: state,
              labels: _labels,
            ),
            MakeupRecommendationStatus.idle => const Center(
              child: StatusState(
                title: 'Recommendation unavailable',
                message: 'Complete your analysis and choose a makeup style.',
                icon: Icons.info_outline_rounded,
              ),
            ),
          },
        ),
      ),
    );
  }
}

class _RecommendationContent extends StatelessWidget {
  const _RecommendationContent({required this.state, required this.labels});

  final MakeupRecommendationState state;
  final Map<String, String> labels;

  @override
  Widget build(BuildContext context) {
    final recommendation = state.recommendation!;
    return ListView(
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(
          'Your personalized palette',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${_label(recommendation.styleCode)} · ${recommendation.overallIntensity} intensity',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...recommendation.items.entries.expand(
          (entry) => [
            RecommendationItemCard(
              title: labels[entry.key] ?? _label(entry.key),
              item: entry.value,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const StatusState(
          title: 'Ready for your preview',
          message:
              'Preview generation is intentionally reserved for Phase 10. Your validated plan is saved securely.',
          icon: Icons.auto_awesome_rounded,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  static String _label(String value) {
    final words = value.replaceAll('_', ' ');
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }
}
