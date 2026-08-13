import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../../analysis/presentation/controllers/face_analysis_controller.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../makeup_styles/presentation/controllers/makeup_style_selection_controller.dart';
import '../../../preview/domain/errors/preview_failure.dart';
import '../../../results/presentation/widgets/before_after_comparison.dart';
import '../../domain/entities/kit_makeup_recommendation.dart';
import '../controllers/makeup_kit_look_controller.dart';
import '../controllers/makeup_kit_look_state.dart';
import '../controllers/makeup_kit_products_controller.dart';
import '../controllers/makeup_kit_products_state.dart';

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
    final isReady =
        analysis != null &&
        style != null &&
        kit.status == MakeupKitProductsStatus.ready &&
        kit.items.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('My Makeup Kit look')),
      body: SafeArea(
        child: PageFrame(
          child: !isReady
              ? _NotReadyState(kit: kit)
              : switch (look.status) {
                  MakeupKitLookStatus.idle => _ReadyState(
                    styleName: style.name,
                    productCount: kit.items.length,
                    onGenerate: () => ref
                        .read(makeupKitLookControllerProvider.notifier)
                        .generate(
                          analysisId: analysis.id,
                          styleCode: style.code,
                        ),
                  ),
                  MakeupKitLookStatus.generatingRecommendation => const Center(
                    child: LoadingState(
                      label: 'Choosing the best products from your kit…',
                    ),
                  ),
                  MakeupKitLookStatus.generatingPreview => const Center(
                    child: LoadingState(
                      label: 'Applying your owned shades to the preview…',
                    ),
                  ),
                  MakeupKitLookStatus.failure => _FailureState(
                    state: look,
                    onRetry: () => ref
                        .read(makeupKitLookControllerProvider.notifier)
                        .retry(),
                    onCreateNewPlan: () {
                      final controller = ref.read(
                        makeupKitLookControllerProvider.notifier,
                      );
                      controller.clear();
                      controller.generate(
                        analysisId: analysis.id,
                        styleCode: style.code,
                      );
                    },
                    onShowPrevious: () => ref
                        .read(makeupKitLookControllerProvider.notifier)
                        .showPreviousResult(),
                  ),
                  MakeupKitLookStatus.success
                      when _linksMatch(look, analysis.id, style.code) =>
                    _KitPreviewContent(
                      state: look,
                      styleName: style.name,
                      onGenerateAnother: () => ref
                          .read(makeupKitLookControllerProvider.notifier)
                          .generateVariation(),
                      onChangeMode: () {
                        ref
                            .read(makeupKitLookControllerProvider.notifier)
                            .clear();
                        context.pop();
                      },
                    ),
                  _ => Center(
                    child: StatusState(
                      title: 'Kit preview unavailable',
                      message:
                          'This preview no longer matches the active analysis and style.',
                      icon: Icons.link_off_rounded,
                      actionLabel: 'Choose a mode',
                      onAction: context.pop,
                    ),
                  ),
                },
        ),
      ),
    );
  }

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

class _NotReadyState extends StatelessWidget {
  const _NotReadyState({required this.kit});

  final MakeupKitProductsState kit;

  @override
  Widget build(BuildContext context) => Center(
    child: StatusState(
      title: 'Your kit is not ready',
      message: kit.items.isEmpty
          ? 'Add at least one product before creating a kit-based look.'
          : 'Return to your analysis and style selection.',
      icon: Icons.inventory_2_outlined,
      actionLabel: kit.items.isEmpty ? 'Add Product' : 'Change mode',
      onAction: kit.items.isEmpty
          ? () => context.push(AppConstants.makeupKitAddProductRoute)
          : context.pop,
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
    child: StatusState(
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
  });

  final MakeupKitLookState state;
  final VoidCallback onRetry;
  final VoidCallback onCreateNewPlan;
  final VoidCallback onShowPrevious;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authentication =
        state.failureType == PreviewFailureType.authentication;
    final inventoryChanged = state.technicalCode == 'INVENTORY_CHANGED';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusState(
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
        ],
      ),
    );
  }
}

class _KitPreviewContent extends StatelessWidget {
  const _KitPreviewContent({
    required this.state,
    required this.styleName,
    required this.onGenerateAnother,
    required this.onChangeMode,
  });

  final MakeupKitLookState state;
  final String styleName;
  final VoidCallback onGenerateAnother;
  final VoidCallback onChangeMode;

  @override
  Widget build(BuildContext context) {
    final preview = state.preview!;
    final recommendation = state.recommendation!;
    return ListView(
      children: [
        Text(
          'Your kit-based preview',
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
        BeforeAfterComparison(
          originalImageUrl: preview.originalImageUrl,
          generatedImageUrl: preview.generatedImageUrl,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recommendation.summary,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${recommendation.selections.length} owned product${recommendation.selections.length == 1 ? '' : 's'} selected · ${recommendation.overallIntensity} intensity',
              ),
              const SizedBox(height: AppSpacing.md),
              ...recommendation.selections.map(_SelectionRow.new),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: 'Generate another variation',
          icon: Icons.refresh_rounded,
          onPressed: onGenerateAnother,
        ),
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(label: 'Change mode', onPressed: onChangeMode),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _SelectionRow extends StatelessWidget {
  const _SelectionRow(this.selection);

  final KitMakeupSelection selection;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(
              int.parse(selection.colorHex.substring(1), radix: 16) |
                  0xFF000000,
            ),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            '${_label(selection.category)} · ${_label(selection.finish)} · ${selection.intensity}',
          ),
        ),
      ],
    ),
  );

  static String _label(String value) {
    final words = value.replaceAll('_', ' ');
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }
}
