import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../analysis/presentation/controllers/face_analysis_controller.dart';
import '../../../recommendation/presentation/controllers/makeup_recommendation_controller.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/catalog/makeup_style_catalog.dart';
import '../controllers/makeup_style_selection_controller.dart';
import '../widgets/makeup_style_card.dart';

class StyleSelectionPage extends ConsumerWidget {
  const StyleSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(makeupStyleSelectionControllerProvider);
    final controller = ref.read(
      makeupStyleSelectionControllerProvider.notifier,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your style')),
      body: SafeArea(
        child: PageFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Which look feels like you?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your analysis is saved for this scan, so you can go back and compare styles without rerunning it.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.taupe),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 720 ? 3 : 2;
                    return GridView.builder(
                      semanticChildCount: MakeupStyleCatalog.styles.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: 190,
                        crossAxisSpacing: AppSpacing.sm,
                        mainAxisSpacing: AppSpacing.sm,
                      ),
                      itemCount: MakeupStyleCatalog.styles.length,
                      itemBuilder: (context, index) {
                        final style = MakeupStyleCatalog.styles[index];
                        return MakeupStyleCard(
                          key: ValueKey(style.code),
                          style: style,
                          isSelected: state.selectedStyle?.id == style.id,
                          onSelected: () => controller.select(style),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (state.isConfirmed) ...[
                AppCard(
                  color: AppColors.petal,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '${state.selectedStyle!.name} is saved for this scan and ready for recommendation generation.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              PrimaryButton(
                label: state.isConfirmed
                    ? '${state.selectedStyle!.name} selected'
                    : state.selectedStyle == null
                    ? 'Select a style to continue'
                    : 'Continue with ${state.selectedStyle!.name}',
                icon: state.isConfirmed
                    ? Icons.check_rounded
                    : Icons.arrow_forward_rounded,
                onPressed: state.selectedStyle == null
                    ? null
                    : () {
                        final analysis = ref
                            .read(faceAnalysisControllerProvider)
                            .analysis;
                        if (analysis == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Return to analysis before generating a recommendation.',
                              ),
                            ),
                          );
                          return;
                        }
                        controller.confirm();
                        ref
                            .read(
                              makeupRecommendationControllerProvider.notifier,
                            )
                            .generate(
                              analysis: analysis,
                              style: state.selectedStyle!,
                            );
                        context.push(AppConstants.recommendationRoute);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
