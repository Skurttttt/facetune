import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
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
import '../../../tutorial/data/providers/tutorial_providers.dart';
import '../../../tutorial/domain/catalog/realized_look_filter.dart';
import '../../../tutorial/domain/entities/canonical_preview_ref.dart';
import '../../../tutorial/presentation/controllers/realized_look_controller.dart';
import '../../../tutorial/presentation/pages/tutorial_page.dart';
import '../../../tutorial/presentation/utils/tutorial_labels.dart';
import '../../../results/presentation/widgets/recommended_palette.dart';
import '../../../results/presentation/widgets/result_actions.dart';
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
      // Same message, same two recovery actions, same conditions. The tone is
      // read from state the controller already publishes rather than derived
      // from the text: an expired session or a failed saved-status lookup is a
      // failure, and everything else here is a confirmation.
      final isFailure = next.sessionExpired || canRetrySavedStatus;
      showAppSnackBar(
        context,
        message: next.feedback!,
        tone: isFailure ? AppTone.danger : AppTone.success,
        actionLabel: next.sessionExpired
            ? 'Sign in again'
            : canRetrySavedStatus
            ? 'Retry'
            : null,
        onAction: next.sessionExpired
            ? () => ref
                  .read(authControllerProvider.notifier)
                  .recoverExpiredSession()
            : canRetrySavedStatus
            ? () => ref
                  .read(resultActionsControllerProvider.notifier)
                  .retrySavedStatus(currentPreview)
            : null,
      );
      ref.read(resultActionsControllerProvider.notifier).clearFeedback();
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Your FaceTune result')),
      body: SafeArea(
        child: PageFrame(
          // Wider than the 720 default so the side-by-side branch below can
          // actually engage. It never could: `PageFrame` capped this page's
          // child at 720, and the layout asked for 900 — dead code that read
          // like a working tablet layout. This is the only screen that earns
          // the extra width, because it is the only one with two things worth
          // reading at once.
          maxWidth: 1000,
          child: switch (previewState.status) {
            MakeupPreviewStatus.generating => const Center(
              child: LoadingState(
                label: 'Creating another identity-conscious variation…',
              ),
            ),
            MakeupPreviewStatus.failure => _ScrollableStateRegion(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusState.error(
                    title: 'Preview generation paused',
                    message: previewState.message ?? 'Please try again.',
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
                    TertiaryButton(
                      label: 'View previous result',
                      icon: Icons.undo_rounded,
                      onPressed: () => ref
                          .read(makeupPreviewControllerProvider.notifier)
                          .showPreviousResult(),
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
              ),
            MakeupPreviewStatus.success => _ScrollableStateRegion(
              // A broken referential chain between analysis, plan and preview
              // is a failure, not an absence — the guard above rejected a
              // result that had actually been generated.
              child: StatusState.error(
                title: 'Result links unavailable',
                message:
                    'This preview no longer matches the active analysis and makeup plan.',
                icon: Icons.link_off_rounded,
                actionLabel: 'Return to makeup plan',
                onAction: () => context.go(AppConstants.recommendationRoute),
              ),
            ),
            _ => _ScrollableStateRegion(
              // Reaching this screen with nothing generated yet is a missing
              // precondition, not a fault, so it stays neutral and quiet.
              child: StatusState.info(
                title: 'Result unavailable',
                message:
                    'Complete analysis, recommendation, and preview generation to view your result.',
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

/// Keeps compact page states centred while allowing them to scroll when large
/// text makes them taller than the viewport.
class _ScrollableStateRegion extends StatelessWidget {
  const _ScrollableStateRegion({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(child: child),
      ),
    ),
  );
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
      generatedImageUrl: preview.generatedImageUrl,
      onSave: onSave,
      onFavorite: onFavorite,
      onShare: onShare,
      onGenerateAnother: onGenerateAnother,
      onReturnHome: onReturnHome,
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
    required this.generatedImageUrl,
    required this.onSave,
    required this.onFavorite,
    required this.onShare,
    required this.onGenerateAnother,
    required this.onReturnHome,
  });

  final FaceAnalysis analysis;
  final MakeupRecommendation recommendation;
  final String styleName;
  final ResultActionsState actionState;
  final String previewId;

  /// Reused as the tutorial's closing image, so the end of the tutorial shows
  /// the look the user already has rather than generating it again.
  final String generatedImageUrl;

  final VoidCallback onSave;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onGenerateAnother;
  final VoidCallback onReturnHome;

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
      _RealizedBreakdown(
        preview: CanonicalPreviewRef.standard(previewId),
        recommendation: recommendation,
      ),
      const SizedBox(height: AppSpacing.lg),
      // The tutorial entry point. Deliberately a secondary action beside the
      // existing ones rather than a redesign of this screen: opening it starts
      // no AI work, and the tutorial decides for itself what it already has.
      SecondaryButton(
        label: TutorialLabels.startTutorial,
        icon: Icons.auto_stories_outlined,
        onPressed: () => context.push(
          AppConstants.tutorialRoute,
          extra: TutorialPageArgs(
            preview: CanonicalPreviewRef.standard(previewId),
            finalPreviewUrl: generatedImageUrl,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
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
    ],
  );
}

/// The Makeup Breakdown, filtered to what the canonical preview actually shows.
///
/// A `ConsumerStatefulWidget` so the manifest is ensured from `initState`
/// rather than from `build`. That is the same discipline the tutorial page
/// follows and for the same reason: a build runs for reasons that have nothing
/// to do with intent — a snackbar, a theme change, a parent rebuilding — and
/// starting paid analysis from one would be a bug the user pays for.
///
/// Ensuring is idempotent and reuse-first, so whichever consumer arrives first
/// for a given preview causes at most one analysis and every later arrival
/// resolves from persistence. Opening the tutorial afterwards analyses nothing.
class _RealizedBreakdown extends ConsumerStatefulWidget {
  const _RealizedBreakdown({
    required this.preview,
    required this.recommendation,
  });

  final CanonicalPreviewRef preview;
  final MakeupRecommendation recommendation;

  @override
  ConsumerState<_RealizedBreakdown> createState() => _RealizedBreakdownState();
}

class _RealizedBreakdownState extends ConsumerState<_RealizedBreakdown> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(realizedLookControllerProvider.notifier).ensure(widget.preview);
    });
  }

  @override
  void didUpdateWidget(_RealizedBreakdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Generating a variation replaces the canonical preview, and the previous
    // preview's manifest is not authoritative for it.
    if (oldWidget.preview != widget.preview) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(realizedLookControllerProvider.notifier)
            .ensure(widget.preview);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(realizedLookControllerProvider);
    // A result for a different preview is not evidence about this one.
    final isThisPreview = state.preview == widget.preview;
    if (!isThisPreview ||
        state.status == RealizedLookStatus.idle ||
        state.status == RealizedLookStatus.ensuring) {
      // Deliberately a wait rather than the unfiltered recommendation. Showing
      // nine categories and then correcting to eight would tell the user
      // something false, and being briefly false does not make it harmless.
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: LoadingState(label: 'Checking what this look actually used…'),
      );
    }
    if (state.status != RealizedLookStatus.ready) {
      // Never falls back to the full recommendation: that is exactly the
      // second, weaker category authority this phase removed.
      return StatusState.error(
        title: 'Breakdown unavailable',
        message:
            state.message ??
            'This look could not be checked against your final preview.',
        actionLabel: state.retryable ? 'Try again' : null,
        onAction: state.retryable
            ? () => ref.read(realizedLookControllerProvider.notifier).retry()
            : null,
      );
    }
    return MakeupBreakdown(
      groups: RealizedLookFilter.standardGroups(
        recommendation: widget.recommendation,
        included: state.includedCategories,
      ),
    );
  }
}
