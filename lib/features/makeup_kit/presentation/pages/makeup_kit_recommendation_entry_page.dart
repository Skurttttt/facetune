import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';
import '../../../analysis/presentation/controllers/face_analysis_controller.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../makeup_styles/presentation/controllers/makeup_style_selection_controller.dart';
import '../../../preview/domain/errors/preview_failure.dart';
import '../../../analysis/domain/entities/face_analysis.dart';
import '../../../results/presentation/utils/result_formatters.dart';
import '../../../results/presentation/widgets/beauty_profile_card.dart';
import '../../../results/presentation/widgets/before_after_comparison.dart';
import '../../../results/presentation/widgets/result_actions.dart';
import '../../../results/presentation/widgets/result_shell.dart';
import '../widgets/kit_product_palette.dart';
import '../controllers/makeup_kit_look_controller.dart';
import '../controllers/makeup_kit_look_state.dart';
import '../controllers/makeup_kit_products_controller.dart';
import '../controllers/makeup_kit_products_state.dart';
import '../controllers/makeup_kit_result_actions_controller.dart';
import '../controllers/makeup_kit_result_actions_state.dart';
import '../widgets/kit_result_product_card.dart';
import '../../../tutorial/data/providers/tutorial_providers.dart';
import '../../../tutorial/domain/catalog/realized_look_filter.dart';
import '../../../tutorial/domain/entities/canonical_preview_ref.dart';
import '../../../tutorial/presentation/controllers/realized_look_controller.dart';
import '../../domain/entities/kit_makeup_recommendation.dart';
import '../../../tutorial/presentation/pages/tutorial_page.dart';
import '../../../tutorial/presentation/utils/tutorial_labels.dart';

class MakeupKitRecommendationEntryPage extends ConsumerWidget {
  const MakeupKitRecommendationEntryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(faceAnalysisControllerProvider).analysis;
    final style = ref
        .watch(makeupStyleSelectionControllerProvider)
        .selectedStyle;
    final kit = ref.watch(makeupKitProductsControllerProvider);
    final look = ref.watch(makeupKitLookControllerProvider);
    final actions = ref.watch(makeupKitResultActionsControllerProvider);
    final kitReady =
        analysis != null &&
        style != null &&
        kit.status == MakeupKitProductsStatus.ready &&
        kit.items.isNotEmpty;
    final resultReady =
        look.status == MakeupKitLookStatus.success &&
        analysis != null &&
        style != null &&
        _linksMatch(look, analysis.id, style.code);
    final preview = look.preview;
    if (preview != null && !actions.loadedPreviewIds.contains(preview.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(makeupKitResultActionsControllerProvider.notifier)
            .loadSavedStatus(preview);
      });
    }
    ref.listen<MakeupKitResultActionsState>(
      makeupKitResultActionsControllerProvider,
      (previous, next) {
        if (next.feedback == null || next.feedback == previous?.feedback) {
          return;
        }
        showAppSnackBar(
          context,
          message: next.feedback!,
          tone: next.sessionExpired ? AppTone.danger : AppTone.success,
          actionLabel: next.sessionExpired ? 'Sign in again' : null,
          onAction: next.sessionExpired
              ? () => ref
                    .read(authControllerProvider.notifier)
                    .recoverExpiredSession()
              : null,
        );
        ref
            .read(makeupKitResultActionsControllerProvider.notifier)
            .clearFeedback();
      },
    );

    return Scaffold(
      // No page title, exactly as Standard has none: the look's own name is the
      // title and it is the first thing under this bar. "My Makeup Kit look" up
      // here was a third heading saying what two others already said.
      //
      // Home is the same top-right utility Standard uses, and it replaces the
      // "Return home" text action that used to sit at the bottom of the button
      // stack. One Home per screen.
      appBar: FaceTuneTopBar(
        // Titled only while the makeup plan is being made, which is the one
        // state on this screen with no heading of its own to read — and it is
        // the title Makeup Recommendation carries through the same wait, so the
        // two modes wait under the same bar. Every other state keeps the bare
        // bar it has today.
        title: look.status == MakeupKitLookStatus.generatingRecommendation
            ? 'Your makeup plan'
            : null,
        actions: resultReady
            ? <Widget>[
                _KitHomeAction(
                  onPressed: () => context.go(AppConstants.homeRoute),
                ),
              ]
            : null,
      ),
      // The same reserved bottom strip Standard uses, carrying the same single
      // CTA. The tutorial it opens is the kit's own: a My Makeup Kit canonical
      // preview reference, which is what carries the source mode through to the
      // tutorial's manifest and steps. No Standard crossover.
      bottomNavigationBar: resultReady
          ? ResultBottomCta(
              key: const ValueKey('result-primary-actions'),
              label: TutorialLabels.startTutorial,
              onPressed: () => context.push(
                AppConstants.tutorialRoute,
                extra: TutorialPageArgs(
                  preview: CanonicalPreviewRef.myMakeupKit(preview!.id),
                  finalPreviewUrl: preview.generatedImageUrl,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: PageFrame(
          maxWidth: 1000,
          // The bottom bar already provides the navigation-bar clearance
          // `PageFrame`'s tail exists for, so keeping both would reserve the
          // same space twice. Dropped only while the bar is there.
          padding: resultReady
              ? PageFrame.defaultPadding.copyWith(bottom: 0)
              : PageFrame.defaultPadding,
          child: resultReady
              ? _KitPreviewContent(
                  state: look,
                  styleName: style.name,
                  analysis: analysis,
                  actions: actions,
                  onFavorite: () => ref
                      .read(makeupKitResultActionsControllerProvider.notifier)
                      .toggleFavorite(preview!),
                  onShare: () => ref
                      .read(makeupKitResultActionsControllerProvider.notifier)
                      .share(preview: preview!, styleName: style.name),
                  onGenerateAnother: () => ref
                      .read(makeupKitLookControllerProvider.notifier)
                      .generateVariation(),
                )
              : !kitReady
              ? _NotReadyState(
                  kit: kit,
                  analysisReady: analysis != null,
                  styleReady: style != null,
                )
              : _activeState(
                  context,
                  ref,
                  look,
                  analysis.id,
                  style.code,
                  style.name,
                  kit.items.length,
                ),
        ),
      ),
    );
  }

  Widget _activeState(
    BuildContext context,
    WidgetRef ref,
    MakeupKitLookState look,
    String analysisId,
    String styleCode,
    String styleName,
    int productCount,
  ) => switch (look.status) {
    MakeupKitLookStatus.idle => _ReadyState(
      styleName: styleName,
      productCount: productCount,
      onGenerate: () => ref
          .read(makeupKitLookControllerProvider.notifier)
          .generate(analysisId: analysisId, styleCode: styleCode),
    ),
    // The plan stage, in the same shell Makeup Recommendation waits in: same
    // heading slot, same supporting line, same destination-shaped placeholders,
    // same spacing and same pulse. Only the supporting copy differs, and it
    // differs because the work differs — this mode is choosing among products
    // the user already owns. It is read from the mode the user already picked;
    // nothing is fetched to say it.
    //
    // The escape this state has always offered is preserved rather than dropped
    // for symmetry: it clears this mode's own controller and pops, exactly as
    // before. No Standard controller, repository or recommendation is touched.
    MakeupKitLookStatus.generatingRecommendation => MakeupPlanLoadingView(
      key: const ValueKey('makeup-plan-loading'),
      title: 'Creating your makeup plan',
      supportingText: 'Personalizing your owned products for your features.',
      footer: TextButton(
        onPressed: () {
          ref.read(makeupKitLookControllerProvider.notifier).clear();
          context.pop();
        },
        child: const Text('Cancel and change mode'),
      ),
    ),
    // The same shell Makeup Recommendation waits in, with the same hero frame,
    // spacing, status and reassurance. Only the supporting line differs, and it
    // differs because the work does — this preview is built from the products
    // the user owns. Style and intensity come from state this mode already
    // holds: the selected style, and the kit plan this generation is running
    // from. Nothing is fetched, and no Standard recommendation is consulted.
    //
    // The escape this state has always offered is preserved rather than dropped
    // for symmetry: it clears this mode's own controller and pops, exactly as
    // before.
    MakeupKitLookStatus.generatingPreview => FinalPreviewLoadingView(
      key: const ValueKey('final-preview-loading'),
      supportingText:
          'Using your selected makeup products to create your preview.',
      styleName: styleName,
      // The same formatter Standard's loading screen uses, so one intensity
      // reads identically in both modes.
      intensityLabel: look.recommendation == null
          ? null
          : ResultFormatters.label(look.recommendation!.overallIntensity),
      footer: TextButton(
        onPressed: () {
          ref.read(makeupKitLookControllerProvider.notifier).clear();
          context.pop();
        },
        child: const Text('Cancel and change mode'),
      ),
    ),
    MakeupKitLookStatus.failure => _FailureState(
      state: look,
      onRetry: () => ref.read(makeupKitLookControllerProvider.notifier).retry(),
      onCreateNewPlan: () {
        final controller = ref.read(makeupKitLookControllerProvider.notifier);
        controller.clear();
        controller.generate(analysisId: analysisId, styleCode: styleCode);
      },
      onShowPrevious: () => ref
          .read(makeupKitLookControllerProvider.notifier)
          .showPreviousResult(),
      onChangeMode: () {
        ref.read(makeupKitLookControllerProvider.notifier).clear();
        context.pop();
      },
    ),
    _ => Center(
      child: StatusState.error(
        title: 'Kit preview unavailable',
        message:
            'This preview no longer matches the active analysis and style.',
        icon: Icons.link_off_rounded,
        actionLabel: 'Choose a mode',
        onAction: context.pop,
      ),
    ),
  };

  static bool _linksMatch(
    MakeupKitLookState state,
    String analysisId,
    String styleCode,
  ) {
    final recommendation = state.recommendation;
    final preview = state.preview;
    return recommendation != null &&
        preview != null &&
        recommendation.analysisId == analysisId &&
        recommendation.styleCode == styleCode &&
        preview.analysisId == analysisId &&
        preview.kitRecommendationId == recommendation.id;
  }
}

class _NotReadyState extends ConsumerWidget {
  const _NotReadyState({
    required this.kit,
    required this.analysisReady,
    required this.styleReady,
  });

  final MakeupKitProductsState kit;
  final bool analysisReady;
  final bool styleReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kit.status == MakeupKitProductsStatus.loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LoadingState(label: 'Checking your makeup kit…'),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: context.pop,
              child: const Text('Change mode'),
            ),
          ],
        ),
      );
    }
    if (kit.status == MakeupKitProductsStatus.failure) {
      return Center(
        child: StatusState.error(
          title: 'Your kit could not be checked',
          message: kit.message ?? 'Please try again.',
          icon: Icons.cloud_off_outlined,
          actionLabel: kit.sessionExpired ? 'Sign in again' : 'Try again',
          onAction: kit.sessionExpired
              ? () => ref
                    .read(authControllerProvider.notifier)
                    .recoverExpiredSession()
              : () => ref
                    .read(makeupKitProductsControllerProvider.notifier)
                    .refresh(),
          secondaryActionLabel: 'Change mode',
          onSecondaryAction: context.pop,
        ),
      );
    }
    final journeyReady = analysisReady && styleReady;
    return Center(
      // Neither branch is a failure. An empty kit is the starting state for a
      // new account, and an incomplete scan is a missing precondition — both
      // have a clear next step and neither is anyone's fault.
      child: StatusState.info(
        title: kit.items.isEmpty
            ? 'Your kit is empty'
            : 'Your scan is not ready',
        message: kit.items.isEmpty
            ? 'Add at least one product before creating a kit-based look.'
            : 'Complete your analysis and style selection first.',
        icon: Icons.inventory_2_outlined,
        actionLabel: kit.items.isEmpty ? 'Add Product' : 'Change mode',
        onAction: kit.items.isEmpty
            ? () => context.push(AppConstants.makeupKitAddProductRoute)
            : context.pop,
        secondaryActionLabel: kit.items.isEmpty && journeyReady
            ? 'Change mode'
            : null,
        onSecondaryAction: context.pop,
      ),
    );
  }
}

class _ReadyState extends StatelessWidget {
  const _ReadyState({
    required this.styleName,
    required this.productCount,
    required this.onGenerate,
  });

  final String styleName;
  final int productCount;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) => Center(
    // An invitation, not a completed outcome — so info rather than success.
    child: StatusState.info(
      title: 'Your kit is ready',
      message:
          '$styleName will use the best honest combination from your $productCount owned product${productCount == 1 ? '' : 's'}. Missing categories are okay.',
      icon: Icons.inventory_2_outlined,
      actionLabel: 'Create kit-based preview',
      onAction: onGenerate,
      secondaryActionLabel: 'Change mode',
      onSecondaryAction: context.pop,
    ),
  );
}

class _FailureState extends ConsumerWidget {
  const _FailureState({
    required this.state,
    required this.onRetry,
    required this.onCreateNewPlan,
    required this.onShowPrevious,
    required this.onChangeMode,
  });

  final MakeupKitLookState state;
  final VoidCallback onRetry;
  final VoidCallback onCreateNewPlan;
  final VoidCallback onShowPrevious;
  final VoidCallback onChangeMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authentication =
        state.failureType == PreviewFailureType.authentication;
    final inventoryChanged = state.technicalCode == 'INVENTORY_CHANGED';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusState.error(
            title: inventoryChanged
                ? 'Your kit changed'
                : 'Kit preview generation paused',
            message: state.message ?? 'Please try again.',
            icon: Icons.error_outline_rounded,
            actionLabel: authentication
                ? 'Sign in again'
                : inventoryChanged
                ? 'Create a new plan'
                : state.retryable
                ? 'Try again'
                : null,
            onAction: authentication
                ? () => ref
                      .read(authControllerProvider.notifier)
                      .recoverExpiredSession()
                : inventoryChanged
                ? onCreateNewPlan
                : state.retryable
                ? onRetry
                : null,
          ),
          if (state.previousPreview != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: onShowPrevious,
              icon: const Icon(Icons.undo_rounded),
              label: const Text('View previous result'),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          TextButton(onPressed: onChangeMode, child: const Text('Change mode')),
        ],
      ),
    );
  }
}

/// The kit result, in the same shell Standard uses.
///
/// This screen used to be a scrolling stack: two headings that said the same
/// thing, a full-width tinted notice, the hero, a paragraph of summary, the
/// breakdown, and then six full-width buttons in a column. It was not a worse
/// design so much as a different product — a user arriving from Standard had to
/// re-learn where everything was.
///
/// It now composes [ResultHeader], [ResultSections] and [ResultBottomCta] — the
/// same widgets Standard composes, in the same order, with the same spacing.
/// Every piece of data still comes from kit authorities: the validated
/// recommendation and its immutable product snapshots. Nothing here reads a
/// Standard recommendation, and nothing falls back to one.
class _KitPreviewContent extends StatelessWidget {
  const _KitPreviewContent({
    required this.state,
    required this.styleName,
    required this.analysis,
    required this.actions,
    required this.onFavorite,
    required this.onShare,
    required this.onGenerateAnother,
  });

  final MakeupKitLookState state;
  final String styleName;
  final FaceAnalysis analysis;
  final MakeupKitResultActionsState actions;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onGenerateAnother;

  @override
  Widget build(BuildContext context) {
    final preview = state.preview!;
    final recommendation = state.recommendation!;
    final productCount = recommendation.selections.length;
    return ListView(
      key: const ValueKey('result-content-scroll'),
      children: [
        // Provenance as a label, not a card. The old full-width success notice
        // said "Created only from products registered in My Makeup Kit" in a
        // paragraph that outweighed the look it described; the badge says the
        // same thing in the place a user looks for what they are reading.
        //
        // The variation number is gone from the hero for the same reason it
        // left Standard's: it is bookkeeping about how the image was produced.
        // It remains on the preview and in kit history, where it distinguishes
        // one saved look from another.
        // No mode label. The metadata line already says the look was built from
        // owned products, and a badge above the title made the kit result read
        // as a labelled variant of the app rather than the same result screen
        // with a different source.
        ResultHeader(
          styleName: styleName,
          metadata:
              '$productCount owned product${productCount == 1 ? '' : 's'} · '
              '${_label(recommendation.overallIntensity)} intensity',
        ),
        const SizedBox(height: AppSpacing.md),
        // The same hero component Standard uses, given kit artifacts. Same
        // aspect ratio, same radius, same labels, same drag behaviour — one
        // renderer, two authoritative image pairs.
        BeforeAfterComparison(
          originalImageUrl: preview.originalImageUrl,
          generatedImageUrl: preview.generatedImageUrl,
        ),
        const SizedBox(height: AppSpacing.md),
        ResultSections(
          overview: _KitOverviewSection(
            recommendation: recommendation,
            actions: actions,
            previewId: preview.id,
            onFavorite: onFavorite,
            onShare: onShare,
            onGenerateAnother: onGenerateAnother,
          ),
          makeup: _KitMakeupSection(
            previewId: preview.id,
            recommendation: recommendation,
          ),
          profile: _KitProfileSection(analysis: analysis),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  static String _label(String value) {
    final words = value.replaceAll('_', ' ');
    return words.isEmpty
        ? words
        : '${words[0].toUpperCase()}${words.substring(1)}';
  }
}

/// Overview, kit-side: the owned products, then the same utility row.
class _KitOverviewSection extends StatelessWidget {
  const _KitOverviewSection({
    required this.recommendation,
    required this.actions,
    required this.previewId,
    required this.onFavorite,
    required this.onShare,
    required this.onGenerateAnother,
  });

  final KitMakeupRecommendation recommendation;
  final MakeupKitResultActionsState actions;
  final String previewId;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onGenerateAnother;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('result-section-overview'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Where Standard says "Recommended palette". Same slot, same component
      // language, different truth: these are products the user owns.
      const SectionHeader('Products from your kit'),
      const SizedBox(height: AppSpacing.sm),
      KitProductPalette(recommendation: recommendation),
      const SizedBox(height: AppSpacing.md),
      // The same three-action row Standard renders, from the same component.
      // Share reaches the app's one share service through the kit controller,
      // carrying the kit's own canonical preview.
      ResultActions(
        isFavorite: actions.isFavorite(previewId),
        isSharing: actions.isSharing,
        isMutating: actions.isMutating,
        onFavorite: onFavorite,
        onShare: onShare,
        onGenerateAnother: onGenerateAnother,
      ),
      // Nothing after the utility row. Leaving this mode is what the global
      // back control is for, and a kit-only action here was the last piece of
      // chrome making this screen look unlike the Standard result.
    ],
  );
}

/// Makeup, kit-side: the same section header, the owned-product breakdown.
class _KitMakeupSection extends StatelessWidget {
  const _KitMakeupSection({
    required this.previewId,
    required this.recommendation,
  });

  final String previewId;
  final KitMakeupRecommendation recommendation;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('result-section-makeup'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeader(
        'Makeup breakdown',
        action: '${_label(recommendation.overallIntensity)} intensity',
      ),
      const SizedBox(height: AppSpacing.sm),
      _RealizedKitBreakdown(
        preview: CanonicalPreviewRef.myMakeupKit(previewId),
        recommendation: recommendation,
      ),
    ],
  );

  static String _label(String value) {
    final words = value.replaceAll('_', ' ');
    return words.isEmpty
        ? words
        : '${words[0].toUpperCase()}${words.substring(1)}';
  }
}

/// Profile, kit-side: the identical component Standard uses.
///
/// Both modes analyse the same face, so there is nothing mode-specific to
/// present. The confidences stay separate and unaggregated, as they are there.
class _KitProfileSection extends StatelessWidget {
  const _KitProfileSection({required this.analysis});

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

/// The owned-product breakdown, filtered to what the canonical preview shows.
///
/// The kit-mode counterpart of the Standard breakdown, and the same join:
/// presence comes from the accepted manifest, product data from the immutable
/// validated snapshot the recommendation already carries. Live inventory is
/// never consulted, so a product edited or deleted since the look was validated
/// still presents as it was used.
///
/// A kit-preview mismatch is surfaced rather than filtered away. Dropping a
/// visibly-present category that no owned product backs would present an
/// unreproducible look as a valid one, which is the opposite of what the
/// mismatch exists to prevent.
class _RealizedKitBreakdown extends ConsumerStatefulWidget {
  const _RealizedKitBreakdown({
    required this.preview,
    required this.recommendation,
  });

  final CanonicalPreviewRef preview;
  final KitMakeupRecommendation recommendation;

  @override
  ConsumerState<_RealizedKitBreakdown> createState() =>
      _RealizedKitBreakdownState();
}

class _RealizedKitBreakdownState extends ConsumerState<_RealizedKitBreakdown> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(realizedLookControllerProvider.notifier).ensure(widget.preview);
    });
  }

  @override
  void didUpdateWidget(_RealizedKitBreakdown oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    final isThisPreview = state.preview == widget.preview;
    if (!isThisPreview ||
        state.status == RealizedLookStatus.idle ||
        state.status == RealizedLookStatus.ensuring) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: LoadingState(label: 'Checking what this look actually used…'),
      );
    }
    if (state.status == RealizedLookStatus.kitPreviewMismatch) {
      // A modelled outcome, not a fault: the preview legitimately shows a
      // category the kit cannot reproduce. Warning rather than danger — nothing
      // failed, but the user does need to know why the breakdown stops here.
      return const StatusState(
        tone: AppTone.warning,
        title: 'This look uses makeup that is not in your kit yet',
        message:
            'The preview shows a category no registered product can reproduce, '
            'so the breakdown cannot be shown as owned products.',
        icon: Icons.inventory_2_outlined,
      );
    }
    if (state.status != RealizedLookStatus.ready) {
      return StatusState.error(
        title: 'Breakdown unavailable',
        message:
            state.message ??
            'This look could not be checked against your final preview.',
        icon: Icons.info_outline_rounded,
        actionLabel: state.retryable ? 'Try again' : null,
        onAction: state.retryable
            ? () => ref.read(realizedLookControllerProvider.notifier).retry()
            : null,
      );
    }
    // One section per manifest category, however many owned products feed it.
    // The kit card is titled by product name, so the canonical category heading
    // is what tells the user which step a product belongs to — and it is what
    // makes this list countable against the tutorial's steps.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in RealizedLookFilter.kitGroups(
          recommendation: widget.recommendation,
          included: state.includedCategories,
        )) ...[
          Text(
            TutorialLabels.categoryName(group.category),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final entry in group.entries) ...[
            KitResultProductCard(
              selection: entry.selection,
              snapshot: widget.recommendation.snapshotFor(
                entry.selection.productId,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }
}

/// Home, as a top-bar utility.
///
/// The same presentation Standard's Home uses, over this screen's own existing
/// destination — the `go` to the home route that the removed "Return home" text
/// action called. Presentation only: no route was added, renamed or rerouted.
class _KitHomeAction extends StatelessWidget {
  const _KitHomeAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      button: true,
      label: 'Home',
      child: IconButton(
        key: const ValueKey('result-home'),
        onPressed: onPressed,
        icon: const Icon(Icons.home_outlined),
      ),
    ),
  );
}
