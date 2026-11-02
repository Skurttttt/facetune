import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../../analysis/presentation/controllers/face_analysis_controller.dart';
import '../../../makeup_kit/domain/entities/makeup_kit_category.dart';
import '../../../makeup_kit/presentation/utils/makeup_kit_display.dart';
import '../../../makeup_styles/presentation/controllers/makeup_style_selection_controller.dart';
import '../../domain/catalog/custom_palette_catalog.dart';
import '../controllers/custom_palette_draft_controller.dart';
import '../controllers/custom_palette_draft_state.dart';
import '../widgets/custom_palette_not_ready_state.dart';
import '../widgets/custom_palette_selection_summary.dart';

/// The palette overview: one card per supported category.
class CustomPalettePage extends ConsumerWidget {
  const CustomPalettePage({super.key});

  static const _title = 'Custom Color Palette';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(faceAnalysisControllerProvider).analysis;
    final style = ref
        .watch(makeupStyleSelectionControllerProvider)
        .selectedStyle;
    final draft = ref.watch(customPaletteDraftControllerProvider);
    if (analysis == null ||
        style == null ||
        draft.analysisId != analysis.id ||
        draft.styleCode != style.code) {
      return const CustomPaletteNotReadyState(title: _title);
    }
    return Scaffold(
      appBar: const FaceTuneTopBar(title: _title),
      body: SafeArea(
        child: PageFrame(
          child: ListView(
            children: [
              Text(
                'Choose your colors',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${style.name} is selected. Turn on the categories you want, '
                'then choose a color and finish for each.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted(context),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final category in CustomPaletteCatalog.categories) ...[
                _CategoryCard(category: category),
                const SizedBox(height: AppSpacing.md),
              ],
              const SizedBox(height: AppSpacing.xs),
              _BlockedReason(draft: draft),
              PrimaryButton(
                label: 'Review palette',
                icon: Icons.arrow_forward_rounded,
                onPressed: draft.isValid
                    ? () => context.push(AppConstants.customPaletteReviewRoute)
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends ConsumerWidget {
  const _CategoryCard({required this.category});

  final MakeupKitCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(
      customPaletteDraftControllerProvider.select(
        (draft) => draft.selectionFor(category),
      ),
    );
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CustomPaletteSelectionSummary(
                  title: category.label,
                  selection: selection,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Semantics(
                label: 'Include ${category.label}',
                child: Switch(
                  value: selection.enabled,
                  onChanged: (enabled) => ref
                      .read(customPaletteDraftControllerProvider.notifier)
                      .setEnabled(category, enabled: enabled),
                ),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TertiaryButton(
              label: selection.base == null
                  ? 'Choose ${category.label}'
                  : 'Edit ${category.label}',
              onPressed: () => context.push(
                AppConstants.customPaletteCategoryLocation(category.code),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Says why Review is unavailable, so the disabled button is never a mystery.
class _BlockedReason extends StatelessWidget {
  const _BlockedReason({required this.draft});

  final CustomPaletteDraftState draft;

  @override
  Widget build(BuildContext context) {
    if (draft.isValid) return const SizedBox.shrink();
    final incomplete = [
      for (final category in draft.enabledCategories)
        if (!draft.selectionFor(category).isComplete) category.label,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        incomplete.isEmpty
            ? 'Turn on at least one category to continue.'
            : 'Choose a color and finish for ${incomplete.join(', ')}.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.muted(context)),
      ),
    );
  }
}
