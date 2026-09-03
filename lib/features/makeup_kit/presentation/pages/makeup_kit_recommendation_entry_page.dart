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
import '../../../results/presentation/widgets/before_after_comparison.dart';
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
      appBar: AppBar(title: const Text('My Makeup Kit look')),
      body: SafeArea(
        child: PageFrame(
          child: resultReady
              ? _KitPreviewContent(
                  state: look,
                  styleName: style.name,
                  actions: actions,
                  onSave: () => ref
                      .read(makeupKitResultActionsControllerProvider.notifier)
                      .toggleSaved(preview!),
                  onFavorite: () => ref
                      .read(makeupKitResultActionsControllerProvider.notifier)
                      .toggleFavorite(preview!),
                  onGenerateAnother: () => ref
                      .read(makeupKitLookControllerProvider.notifier)
                      .generateVariation(),
                  onChangeMode: () {
                    ref.read(makeupKitLookControllerProvider.notifier).clear();
                    context.pop();
                  },
                  onReturnHome: () => context.go(AppConstants.homeRoute),
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
    MakeupKitLookStatus.generatingRecommendation => _GeneratingState(
      label: 'Choosing the best products from your kit…',
      onCancel: () {
        ref.read(makeupKitLookControllerProvider.notifier).clear();
        context.pop();
      },
    ),
    MakeupKitLookStatus.generatingPreview => _GeneratingState(
      label: 'Applying your owned shades to the preview…',
      onCancel: () {
        ref.read(makeupKitLookControllerProvider.notifier).clear();
        context.pop();
      },
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

class _GeneratingState extends StatelessWidget {
  const _GeneratingState({required this.label, required this.onCancel});

  final String label;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LoadingState(label: label),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: onCancel,
          child: const Text('Cancel and change mode'),
        ),
      ],
    ),
  );
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

class _KitPreviewContent extends StatelessWidget {
  const _KitPreviewContent({
    required this.state,
    required this.styleName,
    required this.actions,
    required this.onSave,
    required this.onFavorite,
    required this.onGenerateAnother,
    required this.onChangeMode,
    required this.onReturnHome,
  });

  final MakeupKitLookState state;
  final String styleName;
  final MakeupKitResultActionsState actions;
  final VoidCallback onSave;
  final VoidCallback onFavorite;
  final VoidCallback onGenerateAnother;
  final VoidCallback onChangeMode;
  final VoidCallback onReturnHome;

  @override
  Widget build(BuildContext context) {
    final preview = state.preview!;
    final recommendation = state.recommendation!;
    return ListView(
      children: [
        Text(
          'Your My Makeup Kit look',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '$styleName · Variation ${preview.generationNumber}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.rose,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // The ownership guarantee — this look used nothing the user does not
        // own. Stated as a confirmation rather than a neutral aside, because it
        // is the whole promise of kit mode.
        const AppNotice(
          tone: AppTone.success,
          icon: Icons.inventory_2_outlined,
          message: 'Created only from products registered in My Makeup Kit.',
        ),
        const SizedBox(height: AppSpacing.md),
        BeforeAfterComparison(
          originalImageUrl: preview.originalImageUrl,
          generatedImageUrl: preview.generatedImageUrl,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          recommendation.summary,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${recommendation.selections.length} owned product${recommendation.selections.length == 1 ? '' : 's'} selected · ${recommendation.overallIntensity} intensity',
        ),
        const SizedBox(height: AppSpacing.md),
        _RealizedKitBreakdown(
          preview: CanonicalPreviewRef.myMakeupKit(preview.id),
          recommendation: recommendation,
        ),
        const SizedBox(height: AppSpacing.sm),
        // The kit-mode tutorial entry. The same screen and the same controller
        // as Standard Mode — only the preview reference differs, which is what
        // carries the source mode through.
        SecondaryButton(
          label: TutorialLabels.startTutorial,
          icon: Icons.auto_stories_outlined,
          onPressed: () => context.push(
            AppConstants.tutorialRoute,
            extra: TutorialPageArgs(
              preview: CanonicalPreviewRef.myMakeupKit(preview.id),
              finalPreviewUrl: preview.generatedImageUrl,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        PrimaryButton(
          label: actions.isSaved(preview.id) ? 'Saved' : 'Save look',
          icon: actions.isSaved(preview.id)
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          onPressed: actions.isMutating ? null : onSave,
        ),
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          label: actions.isFavorite(preview.id) ? 'Favorited' : 'Favorite',
          icon: actions.isFavorite(preview.id)
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          onPressed: actions.isMutating ? null : onFavorite,
        ),
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          label: 'Generate another variation',
          icon: Icons.refresh_rounded,
          onPressed: onGenerateAnother,
        ),
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(label: 'Change mode', onPressed: onChangeMode),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: onReturnHome,
          icon: const Icon(Icons.home_outlined),
          label: const Text('Return home'),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
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
