import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../analysis/presentation/controllers/face_analysis_controller.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
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
      appBar: const FaceTuneTopBar(title: 'Choose your style'),
      body: SafeArea(
        child: PageFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 720 ? 3 : 2;
                    // The cell was a flat 190pt, which clipped the style's
                    // description the moment the reader raised their text size.
                    // The card's fixed furniture — badge, padding, gaps — keeps
                    // its height; both title lines and the description's three
                    // lines grow. Longer names otherwise clip at 2x text once
                    // their lazy grid row scrolls into view.
                    final scaler = MediaQuery.textScalerOf(context);
                    final cellHeight =
                        108 +
                        scaler.scale(16) * 2 * 1.35 +
                        scaler.scale(12) * 3 * 1.45;
                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Which look feels like you?',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Your analysis is saved for this scan, so you can go back and compare styles without rerunning it.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.muted(context)),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                          ),
                        ),
                        SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisExtent: cellHeight,
                                crossAxisSpacing: AppSpacing.sm,
                                mainAxisSpacing: AppSpacing.sm,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final style = MakeupStyleCatalog.styles[index];
                            return MakeupStyleCard(
                              key: ValueKey(style.code),
                              style: style,
                              isSelected: state.selectedStyle?.id == style.id,
                              onSelected: () => controller.select(style),
                            );
                          }, childCount: MakeupStyleCatalog.styles.length),
                        ),
                        if (state.isConfirmed) ...[
                          const SliverToBoxAdapter(
                            child: SizedBox(height: AppSpacing.md),
                          ),
                          SliverToBoxAdapter(
                            // A confirmation, now drawn on the success role
                            // rather than on the same tint used for hints and
                            // failures.
                            child: AppNotice(
                              tone: AppTone.success,
                              message:
                                  '${state.selectedStyle!.name} is saved for this scan and '
                                  'ready for recommendation generation.',
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
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
                          // Same guard, same message, same escape hatch — it
                          // just no longer looks like a neutral notification
                          // when it is telling the user they cannot continue.
                          showAppSnackBar(
                            context,
                            message:
                                'Return to analysis before generating a recommendation.',
                            tone: AppTone.danger,
                            actionLabel: 'Analysis',
                            onAction: () =>
                                context.go(AppConstants.analysisRoute),
                          );
                          return;
                        }
                        controller.confirm();
                        context.push(AppConstants.recommendationModeRoute);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
