import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../../analysis/presentation/controllers/face_analysis_controller.dart';
import '../../../analysis/domain/entities/face_analysis.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../history/presentation/controllers/history_controller.dart';
import '../../../makeup_styles/presentation/controllers/makeup_style_selection_controller.dart';
import '../../../recommendation/presentation/controllers/makeup_recommendation_controller.dart';
import '../../../recommendation/domain/entities/makeup_recommendation.dart';
import '../../../results/presentation/controllers/result_actions_controller.dart';
import '../../../results/presentation/controllers/result_actions_state.dart';
import '../../../results/presentation/utils/result_formatters.dart';
import '../../../results/presentation/widgets/beauty_profile_card.dart';
import '../../../results/presentation/widgets/before_after_comparison.dart';
import '../../../results/presentation/widgets/makeup_breakdown.dart';
import '../../../results/presentation/widgets/recommended_palette.dart';
import '../../../results/presentation/widgets/result_actions.dart';
import '../../../step_by_step_tutorial/domain/entities/tutorial_source_mode.dart';
import '../../../step_by_step_tutorial/presentation/controllers/tutorial_session_controller.dart';
import '../../../step_by_step_tutorial/presentation/widgets/how_to_apply_look_button.dart';
import '../../domain/errors/preview_failure.dart';
import '../controllers/makeup_preview_controller.dart';
import '../controllers/makeup_preview_state.dart';

class PreviewResultPage extends ConsumerWidget {
  const PreviewResultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewState = ref.watch(makeupPreviewControllerProvider);
    final analysis = ref.watch(faceAnalysisControllerProvider).analysis;
    final recommendation = ref
        .watch(makeupRecommendationControllerProvider)
        .recommendation;
    final selectedStyle = ref
        .watch(makeupStyleSelectionControllerProvider)
        .selectedStyle;
    final actionState = ref.watch(resultActionsControllerProvider);
    final preview = previewState.preview;
    if (preview != null && !actionState.loadedPreviewIds.contains(preview.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(resultActionsControllerProvider.notifier)
            .loadSavedStatus(preview);
      });
    }

    ref.listen<ResultActionsState>(resultActionsControllerProvider, (
      previous,
      next,
    ) {
      if (next.feedback == null || next.feedback == previous?.feedback) return;
      final currentPreview = ref.read(makeupPreviewControllerProvider).preview;
      final canRetrySavedStatus =
          !next.sessionExpired &&
          currentPreview != null &&
          next.failedPreviewIds.contains(currentPreview.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next.feedback!),
          action: next.sessionExpired
              ? SnackBarAction(
                  label: 'Sign in again',
                  onPressed: () => ref
                      .read(authControllerProvider.notifier)
                      .recoverExpiredSession(),
                )
              : canRetrySavedStatus
              ? SnackBarAction(
                  label: 'Retry',
                  onPressed: () => ref
                      .read(resultActionsControllerProvider.notifier)
                      .retrySavedStatus(currentPreview),
                )
              : null,
        ),
      );
      ref.read(resultActionsControllerProvider.notifier).clearFeedback();
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Your FaceTune result')),
      body: SafeArea(
        child: PageFrame(
          child: switch (previewState.status) {
            MakeupPreviewStatus.generating => const Center(
              child: LoadingState(
                label: 'Creating another identity-conscious variation…',
              ),
            ),
            MakeupPreviewStatus.failure => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusState(
                    title: 'Preview generation paused',
                    message: previewState.message ?? 'Please try again.',
                    icon: Icons.error_outline_rounded,
                    actionLabel:
                        previewState.failureType ==
                            PreviewFailureType.authentication
                        ? 'Sign in again'
                        : previewState.retryable
                        ? 'Try again'
                        : null,
                    onAction:
                        previewState.failureType ==
                            PreviewFailureType.authentication
                        ? () => ref
                              .read(authControllerProvider.notifier)
                              .recoverExpiredSession()
                        : previewState.retryable
                        ? () => ref
                              .read(makeupPreviewControllerProvider.notifier)
                              .retry()
                        : null,
                    secondaryActionLabel:
                        previewState.failureType ==
                            PreviewFailureType.authentication
                        ? null
                        : 'Return to makeup plan',
                    onSecondaryAction:
                        previewState.failureType ==
                            PreviewFailureType.authentication
                        ? null
                        : () => context.go(AppConstants.recommendationRoute),
                  ),
                  if (previewState.previousPreview != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextButton.icon(
                      onPressed: () => ref
                          .read(makeupPreviewControllerProvider.notifier)
                          .showPreviousResult(),
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('View previous result'),
                    ),
                  ],
                ],
              ),
            ),
            MakeupPreviewStatus.success
                when analysis != null &&
                    recommendation != null &&
                    selectedStyle != null &&
                    preview != null &&
                    analysis.id == recommendation.analysisId &&
                    analysis.id == preview.analysisId &&
                    recommendation.id == preview.recommendationId &&
                    selectedStyle.code == recommendation.styleCode =>
              _ResultContent(
                previewState: previewState,
                analysis: analysis,
                recommendation: recommendation,
                styleName: selectedStyle.name,
                actionState: actionState,
                onSave: () => ref
                    .read(resultActionsControllerProvider.notifier)
                    .toggleSaved(previewState.preview!),
                onFavorite: () => ref
                    .read(resultActionsControllerProvider.notifier)
                    .toggleFavorite(previewState.preview!),
                onShare: () => ref
                    .read(resultActionsControllerProvider.notifier)
                    .share(
                      preview: previewState.preview!,
                      styleName: selectedStyle.name,
                    ),
                onGenerateAnother: () => ref
                    .read(makeupPreviewControllerProvider.notifier)
                    .generateVariation(),
                onReturnHome: () {
                  ref.invalidate(historyControllerProvider);
                  context.go(AppConstants.homeRoute);
                },
                onOpenTutorial: () {
                  ref
                      .read(tutorialSessionControllerProvider.notifier)
                      .load(
                        sourceMode: TutorialSourceMode.standardRecommendation,
                        analysisId: analysis.id,
                        recommendationId: recommendation.id,
                        generationNumber: preview.generationNumber,
                      );
                  context.push(AppConstants.tutorialRoute);
                },
              ),
            MakeupPreviewStatus.success => Center(
              child: StatusState(
                title: 'Result links unavailable',
                message:
                    'This preview no longer matches the active analysis and makeup plan.',
                icon: Icons.link_off_rounded,
                actionLabel: 'Return to makeup plan',
                onAction: () => context.go(AppConstants.recommendationRoute),
              ),
            ),
            _ => Center(
              child: StatusState(
                title: 'Result unavailable',
                message:
                    'Complete analysis, recommendation, and preview generation to view your result.',
                icon: Icons.info_outline_rounded,
                actionLabel: 'Return to makeup plan',
                onAction: () => context.go(AppConstants.recommendationRoute),
              ),
            ),
          },
        ),
      ),
    );
  }
}

class _ResultContent extends StatelessWidget {
  const _ResultContent({
    required this.previewState,
    required this.analysis,
    required this.recommendation,
    required this.styleName,
    required this.actionState,
    required this.onSave,
    required this.onFavorite,
    required this.onShare,
    required this.onGenerateAnother,
    required this.onReturnHome,
    required this.onOpenTutorial,
  });

  final MakeupPreviewState previewState;
  final FaceAnalysis analysis;
  final MakeupRecommendation recommendation;
  final String styleName;
  final ResultActionsState actionState;
  final VoidCallback onSave;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onGenerateAnother;
  final VoidCallback onReturnHome;
  final VoidCallback onOpenTutorial;

  @override
  Widget build(BuildContext context) {
    final preview = previewState.preview!;
    final comparison = BeforeAfterComparison(
      originalImageUrl: preview.originalImageUrl,
      generatedImageUrl: preview.generatedImageUrl,
    );
    final details = _ResultDetails(
      analysis: analysis,
      recommendation: recommendation,
      styleName: styleName,
      actionState: actionState,
      previewId: preview.id,
      onSave: onSave,
      onFavorite: onFavorite,
      onShare: onShare,
      onGenerateAnother: onGenerateAnother,
      onReturnHome: onReturnHome,
      onOpenTutorial: onOpenTutorial,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return ListView(
            children: [
              _ResultHeader(
                styleName: styleName,
                generationNumber: preview.generationNumber,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: comparison),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(child: details),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          );
        }
        return ListView(
          children: [
            _ResultHeader(
              styleName: styleName,
              generationNumber: preview.generationNumber,
            ),
            const SizedBox(height: AppSpacing.lg),
            comparison,
            const SizedBox(height: AppSpacing.lg),
            details,
            const SizedBox(height: AppSpacing.xl),
          ],
        );
      },
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({
    required this.styleName,
    required this.generationNumber,
  });

  final String styleName;
  final int generationNumber;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Your look, revealed',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        '$styleName · Variation $generationNumber',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: AppColors.rose,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Drag across the image to compare. AI identity preservation is a goal, so regenerate if the result does not feel like you.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.muted(context)),
      ),
    ],
  );
}

class _ResultDetails extends StatelessWidget {
  const _ResultDetails({
    required this.analysis,
    required this.recommendation,
    required this.styleName,
    required this.actionState,
    required this.previewId,
    required this.onSave,
    required this.onFavorite,
    required this.onShare,
    required this.onGenerateAnother,
    required this.onReturnHome,
    required this.onOpenTutorial,
  });

  final FaceAnalysis analysis;
  final MakeupRecommendation recommendation;
  final String styleName;
  final ResultActionsState actionState;
  final String previewId;
  final VoidCallback onSave;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onGenerateAnother;
  final VoidCallback onReturnHome;
  final VoidCallback onOpenTutorial;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeader('Detected beauty profile'),
      const SizedBox(height: AppSpacing.sm),
      BeautyProfileCard(analysis: analysis),
      const SizedBox(height: AppSpacing.lg),
      const SectionHeader('Recommended palette'),
      const SizedBox(height: AppSpacing.sm),
      RecommendedPalette(recommendation: recommendation),
      const SizedBox(height: AppSpacing.lg),
      SectionHeader(
        'Makeup breakdown',
        action:
            '${ResultFormatters.label(recommendation.overallIntensity)} intensity',
      ),
      const SizedBox(height: AppSpacing.sm),
      MakeupBreakdown(recommendation: recommendation),
      const SizedBox(height: AppSpacing.lg),
      ResultActions(
        isSaved: actionState.isSaved(previewId),
        isFavorite: actionState.isFavorite(previewId),
        isSharing: actionState.isSharing,
        isMutating: actionState.isMutating,
        onSave: onSave,
        onFavorite: onFavorite,
        onShare: onShare,
        onGenerateAnother: onGenerateAnother,
        onReturnHome: onReturnHome,
      ),
      const SizedBox(height: AppSpacing.sm),
      HowToApplyLookButton(onPressed: onOpenTutorial),
    ],
  );
}
