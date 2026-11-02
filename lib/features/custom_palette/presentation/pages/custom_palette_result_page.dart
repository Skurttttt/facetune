import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';
import '../../../analysis/domain/entities/face_analysis.dart';
import '../../../analysis/presentation/controllers/face_analysis_controller.dart';
import '../../../makeup_kit/presentation/utils/makeup_kit_display.dart';
import '../../../makeup_styles/presentation/controllers/makeup_style_selection_controller.dart';
import '../../../results/presentation/utils/result_formatters.dart';
import '../../../results/presentation/widgets/beauty_profile_card.dart';
import '../../../results/presentation/widgets/before_after_comparison.dart';
import '../../../results/presentation/widgets/result_actions.dart';
import '../../../results/presentation/widgets/result_shell.dart';
import '../../../tutorial/domain/entities/canonical_preview_ref.dart';
import '../../../tutorial/presentation/widgets/tutorial_access_cta.dart';
import '../../domain/entities/custom_palette_look.dart';
import '../controllers/custom_palette_draft_controller.dart';
import '../controllers/custom_palette_library_controllers.dart';
import '../controllers/custom_palette_look_controller.dart';
import '../widgets/custom_palette_not_ready_state.dart';

/// One generated look: the accepted preview and the frozen palette behind it.
///
/// Everything here reads the server's frozen rows, whether the look was just
/// generated or reopened from History. The editor's draft is never consulted, so
/// current choices cannot be shown as what this look used.
class CustomPaletteResultPage extends ConsumerStatefulWidget {
  const CustomPaletteResultPage({super.key});

  @override
  ConsumerState<CustomPaletteResultPage> createState() =>
      _CustomPaletteResultPageState();
}

class _CustomPaletteResultPageState
    extends ConsumerState<CustomPaletteResultPage> {
  String? _loadedSavedStatusFor;

  void _loadSavedStatus(CustomPaletteGeneratedPreview preview) {
    if (_loadedSavedStatusFor == preview.id) return;
    _loadedSavedStatusFor = preview.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(customPaletteResultActionsControllerProvider.notifier)
          .loadSavedStatus(preview);
    });
  }

  /// A new draft from this frozen palette. The look itself cannot change: the new
  /// generation gets its own palette, linked back to this one.
  void _editPalette(CustomPaletteRecommendation recommendation) {
    ref
        .read(customPaletteDraftControllerProvider.notifier)
        .startFromLook(recommendation);
    context.push(AppConstants.customPaletteRoute);
  }

  @override
  Widget build(BuildContext context) {
    final look = ref.watch(customPaletteLookControllerProvider);
    final actions = ref.watch(customPaletteResultActionsControllerProvider);
    final analysis = ref.watch(faceAnalysisControllerProvider).analysis;
    final style = ref
        .watch(makeupStyleSelectionControllerProvider)
        .selectedStyle;
    ref.listen<CustomPaletteResultActionsState>(
      customPaletteResultActionsControllerProvider,
      (previous, next) {
        final feedback = next.feedback;
        if (feedback == null || previous?.feedback == feedback) return;
        showAppSnackBar(
          context,
          message: feedback,
          tone: next.feedbackIsError ? AppTone.danger : AppTone.success,
        );
      },
    );

    final preview = look.preview;
    final recommendation = look.recommendation;
    if (analysis == null || style == null || recommendation == null) {
      return const CustomPaletteNotReadyState(title: 'Your look');
    }
    final ready = look.status == CustomPaletteLookStatus.success;
    if (ready && preview != null) _loadSavedStatus(preview);
    return Scaffold(
      appBar: FaceTuneTopBar(
        title: ready ? null : 'Your look',
        actions: ready
            ? <Widget>[
                TextButton(
                  onPressed: () => context.go(AppConstants.homeRoute),
                  child: const Text('Home'),
                ),
              ]
            : null,
      ),
      bottomNavigationBar: ready && preview != null
          ? TutorialAccessCta(
              preview: CanonicalPreviewRef.customColorPalette(preview.id),
              finalPreviewUrl: preview.generatedImageUrl,
            )
          : null,
      body: SafeArea(
        child: PageFrame(
          maxWidth: 1000,
          padding: ready
              ? PageFrame.defaultPadding.copyWith(bottom: 0)
              : PageFrame.defaultPadding,
          child: switch (look.status) {
            CustomPaletteLookStatus.success when preview != null => ListView(
              key: const ValueKey('custom-palette-result'),
              children: [
                ResultHeader(
                  styleName: style.name,
                  metadata:
                      'Your ${recommendation.palette.length} '
                      'color${recommendation.palette.length == 1 ? '' : 's'} · '
                      '${ResultFormatters.label(recommendation.overallIntensity)} intensity',
                ),
                const SizedBox(height: AppSpacing.md),
                BeforeAfterComparison(
                  originalImageUrl: preview.originalImageUrl,
                  generatedImageUrl: preview.generatedImageUrl,
                ),
                const SizedBox(height: AppSpacing.md),
                ResultSections(
                  overview: _Overview(
                    recommendation: recommendation,
                    actions: actions,
                    previewId: preview.id,
                    onFavorite: () => ref
                        .read(
                          customPaletteResultActionsControllerProvider.notifier,
                        )
                        .toggleFavorite(preview),
                    onShare: () => ref
                        .read(
                          customPaletteResultActionsControllerProvider.notifier,
                        )
                        .share(preview: preview, styleName: style.name),
                    onGenerateAnother: () => ref
                        .read(customPaletteLookControllerProvider.notifier)
                        .generateVariation(),
                    onEditPalette: () => _editPalette(recommendation),
                  ),
                  makeup: _Application(recommendation: recommendation),
                  profile: _Profile(analysis: analysis),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
            CustomPaletteLookStatus.failure => Center(
              child: StatusState.error(
                title: 'Your look could not be created',
                message:
                    look.message ??
                    'Your look could not be created. Please try again.',
                actionLabel: look.retryable ? 'Try again' : 'Edit palette',
                onAction: look.retryable
                    ? () => ref
                          .read(customPaletteLookControllerProvider.notifier)
                          .retry()
                    : () => _editPalette(recommendation),
              ),
            ),
            _ => FinalPreviewLoadingView(
              key: const ValueKey('custom-palette-loading'),
              styleName: style.name,
              intensityLabel: ResultFormatters.label(
                recommendation.overallIntensity,
              ),
              supportingText: 'Applying your colors and finishes.',
            ),
          },
        ),
      ),
    );
  }
}

/// The frozen palette, read from this look's own row.
class CustomPaletteShadeList extends StatelessWidget {
  const CustomPaletteShadeList({required this.palette, super.key});

  final List<CustomPaletteShade> palette;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(
      color: AppColors.muted(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final shade in palette)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: MergeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppColorSwatch(color: shade.adjustedColor.toColor()),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shade.category.label, style: textTheme.titleSmall),
                        Text(
                          '${shade.colorName} (${shade.adjustedColor.value})',
                          style: muted,
                        ),
                        Text('${shade.finish.label} finish', style: muted),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.recommendation,
    required this.actions,
    required this.previewId,
    required this.onFavorite,
    required this.onShare,
    required this.onGenerateAnother,
    required this.onEditPalette,
  });

  final CustomPaletteRecommendation recommendation;
  final CustomPaletteResultActionsState actions;
  final String previewId;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onGenerateAnother;
  final VoidCallback onEditPalette;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('result-section-overview'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeader('Your palette'),
      const SizedBox(height: AppSpacing.sm),
      CustomPaletteShadeList(palette: recommendation.palette),
      const SizedBox(height: AppSpacing.xs),
      ResultActions(
        isFavorite: actions.isFavorite(previewId),
        isSharing: actions.isSharing,
        isMutating: actions.isMutating,
        onFavorite: onFavorite,
        onShare: onShare,
        onGenerateAnother: onGenerateAnother,
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Another variation keeps these colors and finishes.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.muted(context)),
      ),
      const SizedBox(height: AppSpacing.xs),
      TertiaryButton(
        label: 'Edit palette',
        icon: Icons.tune_rounded,
        onPressed: onEditPalette,
      ),
    ],
  );
}

class _Application extends StatelessWidget {
  const _Application({required this.recommendation});

  final CustomPaletteRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      key: const ValueKey('result-section-makeup'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('How to apply it'),
        const SizedBox(height: AppSpacing.sm),
        Text(recommendation.summary, style: textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        for (final shade in recommendation.palette)
          if (recommendation.applicationFor(shade.category)
              case final application?)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shade.category.label, style: textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(application.placement, style: textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(application.technique, style: textTheme.bodyMedium),
                ],
              ),
            ),
      ],
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({required this.analysis});

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
