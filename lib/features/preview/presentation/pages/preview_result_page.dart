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
import '../../../makeup_styles/domain/entities/makeup_style.dart';
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
import '../../../results/presentation/widgets/result_shell.dart';
import '../../domain/entities/generated_preview.dart';
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

    final result = _ResolvedResult.from(
      analysis: analysis,
      recommendation: recommendation,
      style: selectedStyle,
      preview: preview,
    );
    final hasResult =
        previewState.status == MakeupPreviewStatus.success && result != null;

    // The one Home behaviour on this screen. It was a quiet text action at the
    // bottom of the overview list; it is the top-right utility now. Same
    // invalidate, same destination, same order — only the control moved.
    void returnHome() {
      ref.invalidate(historyControllerProvider);
      context.go(AppConstants.homeRoute);
    }

    return Scaffold(
      // No page title. The look's own name is the title, and it is the first
      // thing under this bar — repeating "Your FaceTune result" above it spent
      // the most valuable line on the screen saying what the screen already is.
      //
      // Back on the left goes to the previous route; Home on the right goes to
      // the app's home. Two different journeys, so two different controls.
      appBar: FaceTuneTopBar(
        actions: hasResult
            ? <Widget>[_HomeAction(onPressed: returnHome)]
            : null,
      ),
      // The committing actions own real layout space in the Scaffold rather
      // than floating over the content. This is what keeps the tabs reachable:
      // the body is measured against what is left after the bar, so nothing
      // can ever be scrolled to a position the bar is covering.
      bottomNavigationBar: hasResult
          ? ResultBottomCta(
              key: const ValueKey('result-primary-actions'),
              label: TutorialLabels.startTutorial,
              onPressed: () => context.push(
                AppConstants.tutorialRoute,
                extra: TutorialPageArgs(
                  preview: CanonicalPreviewRef.standard(result.preview.id),
                  finalPreviewUrl: result.preview.generatedImageUrl,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: PageFrame(
          // Wider than the 720 default so the side-by-side branch below can
          // actually engage. It never could: `PageFrame` capped this page's
          // child at 720, and the layout asked for 900 — dead code that read
          // like a working tablet layout. This is the only screen that earns
          // the extra width, because it is the only one with two things worth
          // reading at once.
          maxWidth: 1000,
          // `PageFrame`'s generous bottom tail exists, by its own account, so a
          // screen's last element clears the navigation bar and the gesture
          // area. When the action bar is present it already does that job, and
          // the tail becomes a second reservation for the same thing — 32
          // points of dead scroll stacked under the list's own trailing gap.
          //
          // Dropped only while the bar is there. The loading and error states
          // below render with no bar, and still need the tail.
          padding: hasResult
              ? PageFrame.defaultPadding.copyWith(bottom: 0)
              : PageFrame.defaultPadding,
          child: switch (previewState.status) {
            // The result's own frame, waiting to be filled — not a spinner
            // centred in an empty page. Every value here is already-loaded
            // journey state this page was watching anyway: the selected style
            // and the plan's intensity. Nothing is fetched to draw it, and
            // whichever is missing is simply left out.
            MakeupPreviewStatus.generating => FinalPreviewLoadingView(
              key: const ValueKey('final-preview-loading'),
              supportingText:
                  'Personalizing your makeup preview for your features.',
              styleName: selectedStyle?.name,
              intensityLabel: recommendation == null
                  ? null
                  : ResultFormatters.label(recommendation.overallIntensity),
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
            MakeupPreviewStatus.success when result != null => _ResultContent(
              result: result,
              actionState: actionState,
              onFavorite: () => ref
                  .read(resultActionsControllerProvider.notifier)
                  .toggleFavorite(result.preview),
              onShare: () => ref
                  .read(resultActionsControllerProvider.notifier)
                  .share(preview: result.preview, styleName: result.style.name),
              onGenerateAnother: () => ref
                  .read(makeupPreviewControllerProvider.notifier)
                  .generateVariation(),
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

/// A result whose four parts actually refer to each other.
///
/// The same guard that used to sit in the `switch` above, and the same four
/// identity checks in the same order — moved into a value because two places
/// now need the answer rather than one. The top bar's Save utility is the
/// second: it acts on a preview, and it must not offer to act on one whose
/// links to the analysis and the plan do not hold.
class _ResolvedResult {
  const _ResolvedResult({
    required this.analysis,
    required this.recommendation,
    required this.style,
    required this.preview,
  });

  final FaceAnalysis analysis;
  final MakeupRecommendation recommendation;
  final MakeupStyle style;
  final GeneratedPreview preview;

  /// Null when anything is missing or the chain is broken — which the page
  /// treats as a failure, not an absence, exactly as it did before.
  static _ResolvedResult? from({
    required FaceAnalysis? analysis,
    required MakeupRecommendation? recommendation,
    required MakeupStyle? style,
    required GeneratedPreview? preview,
  }) {
    if (analysis == null ||
        recommendation == null ||
        style == null ||
        preview == null) {
      return null;
    }
    if (analysis.id != recommendation.analysisId ||
        analysis.id != preview.analysisId ||
        recommendation.id != preview.recommendationId ||
        style.code != recommendation.styleCode) {
      return null;
    }
    return _ResolvedResult(
      analysis: analysis,
      recommendation: recommendation,
      style: style,
      preview: preview,
    );
  }
}

/// Home, as a top-bar utility.
///
/// The screen's two navigation escapes now sit at the two top corners, which is
/// where a user looks for them: Back on the left for the previous route, Home
/// on the right for the app's home. Neither does the other's job.
///
/// Presentation only. [onPressed] is the same closure the "Return home" text
/// action at the bottom of the overview list used to call — the same history
/// invalidation followed by the same `go` to the same route.
class _HomeAction extends StatelessWidget {
  const _HomeAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      button: true,
      // Stated rather than left to a tooltip: a house glyph is conventional,
      // but conventional is not the same as announced.
      label: 'Home',
      child: IconButton(
        key: const ValueKey('result-home'),
        onPressed: onPressed,
        icon: const Icon(Icons.home_outlined),
      ),
    ),
  );
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
    required this.result,
    required this.actionState,
    required this.onFavorite,
    required this.onShare,
    required this.onGenerateAnother,
  });

  final _ResolvedResult result;
  final ResultActionsState actionState;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onGenerateAnother;

  @override
  Widget build(BuildContext context) {
    final preview = result.preview;
    final recommendation = result.recommendation;
    final comparison = BeforeAfterComparison(
      originalImageUrl: preview.originalImageUrl,
      generatedImageUrl: preview.generatedImageUrl,
    );
    // The shared section shell, filled with Standard's own content. My Makeup
    // Kit builds the identical shell from its own authorities, which is what
    // makes the two modes read as one product without either borrowing the
    // other's data.
    final details = ResultSections(
      overview: _OverviewSection(
        actionState: actionState,
        previewId: preview.id,
        recommendation: recommendation,
        onFavorite: onFavorite,
        onShare: onShare,
        onGenerateAnother: onGenerateAnother,
      ),
      makeup: _MakeupSection(
        previewId: preview.id,
        recommendation: recommendation,
      ),
      profile: _ProfileSection(analysis: result.analysis),
    );
    // No mode badge. Standard is the default experience, and labelling the
    // default only adds a line to read.
    final header = ResultHeader(
      styleName: result.style.name,
      metadata:
          '${ResultFormatters.label(recommendation.overallIntensity)} intensity · '
          '${ResultFormatters.label(result.analysis.attributes.undertone.name)} undertone',
    );
    // Just the scroll view now. The committing actions moved out to the
    // Scaffold's own bottom slot, so this no longer has to share a column with
    // them — and the height it is given is already what is left over after the
    // bar has taken its space.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return ListView(
            key: const ValueKey('result-content-scroll'),
            children: [
              header,
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: comparison),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(flex: 5, child: details),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          );
        }
        return ListView(
          key: const ValueKey('result-content-scroll'),
          children: [
            header,
            const SizedBox(height: AppSpacing.md),
            comparison,
            const SizedBox(height: AppSpacing.md),
            details,
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      },
    );
  }
}

/// The look's name, and the two facts that qualify it.
///
/// Four blocks of copy used to stand between the top of the screen and the
/// image: a page title, a marketing headline, the style split across two lines
/// with a variation counter, and a sentence of instructions. Each was defensible
/// on its own and together they pushed the one thing the user came for below
/// the fold.
///
/// What is left is what a reader actually needs to name what they are looking
/// at. The style is the title, because it is the true one. The variation number
/// is gone from here — it is bookkeeping about how the image was produced, not
/// a fact about the look, and it remains on the state and in History, where it
/// distinguishes one saved result from another. The comparison instruction now
/// sits on the image it describes.
class _OverviewSection extends StatelessWidget {
  const _OverviewSection({
    required this.actionState,
    required this.previewId,
    required this.recommendation,
    required this.onFavorite,
    required this.onShare,
    required this.onGenerateAnother,
  });

  final ResultActionsState actionState;
  final String previewId;
  final MakeupRecommendation recommendation;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onGenerateAnother;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('result-section-overview'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeader('Recommended palette'),
      const SizedBox(height: AppSpacing.sm),
      RecommendedPalette(recommendation: recommendation),
      const SizedBox(height: AppSpacing.md),
      ResultActions(
        isFavorite: actionState.isFavorite(previewId),
        isSharing: actionState.isSharing,
        isMutating: actionState.isMutating,
        onFavorite: onFavorite,
        onShare: onShare,
        onGenerateAnother: onGenerateAnother,
      ),
    ],
  );
}

class _MakeupSection extends StatelessWidget {
  const _MakeupSection({required this.previewId, required this.recommendation});

  final String previewId;
  final MakeupRecommendation recommendation;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('result-section-makeup'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
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
    ],
  );
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.analysis});

  final FaceAnalysis analysis;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('result-section-profile'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeader('Detected beauty profile'),
      const SizedBox(height: AppSpacing.sm),
      BeautyProfileCard(analysis: analysis),
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
