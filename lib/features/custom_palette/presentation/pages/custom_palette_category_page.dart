import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../../makeup_kit/domain/entities/makeup_kit_category.dart';
import '../../../makeup_kit/domain/entities/makeup_kit_finish.dart';
import '../../../makeup_kit/presentation/utils/makeup_kit_display.dart';
import '../../../makeup_kit/presentation/widgets/makeup_kit_choice_chip_group.dart';
import '../../domain/catalog/custom_palette_catalog.dart';
import '../../domain/catalog/custom_palette_color_model.dart';
import '../controllers/custom_palette_draft_controller.dart';
import '../widgets/custom_palette_color_adjuster.dart';
import '../widgets/custom_palette_not_ready_state.dart';
import '../widgets/custom_palette_selection_summary.dart';
import '../widgets/custom_palette_swatch_grid.dart';

/// The editor for one category: base color, adjustment, finish.
///
/// Changes apply to the draft as they are made, so leaving this page, by Back
/// or by Done, never loses a choice.
class CustomPaletteCategoryPage extends ConsumerWidget {
  const CustomPaletteCategoryPage({required this.categoryCode, super.key});

  final String categoryCode;

  static const _title = 'Custom Color Palette';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = MakeupKitCategory.fromCode(categoryCode);
    final draft = ref.watch(customPaletteDraftControllerProvider);
    if (category == null ||
        !CustomPaletteCatalog.isSupported(category) ||
        draft.analysisId == null) {
      return const CustomPaletteNotReadyState(title: _title);
    }
    final controller = ref.read(customPaletteDraftControllerProvider.notifier);
    final selection = draft.selectionFor(category);
    final base = selection.base;
    return Scaffold(
      appBar: FaceTuneTopBar(title: category.label),
      body: SafeArea(
        child: PageFrame(
          child: ListView(
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: CustomPaletteSelectionSummary(
                  title: 'Your ${category.label.toLowerCase()}',
                  selection: selection,
                  swatchSize: AppColorSwatch.largeSize,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _SectionTitle('Color'),
              const SizedBox(height: AppSpacing.sm),
              CustomPaletteSwatchGrid(
                selected: base,
                onSelected: (swatch) =>
                    controller.selectSwatch(category, swatch),
              ),
              if (base != null) ...[
                const SizedBox(height: AppSpacing.lg),
                const _SectionTitle('Adjust'),
                const SizedBox(height: AppSpacing.sm),
                CustomPaletteColorAdjuster(
                  saturation: selection.saturation,
                  lightness: selection.lightness,
                  saturationEnabled: !CustomPaletteColorModel.toHsl(
                    base.color,
                  ).isAchromatic,
                  canReset: selection.isAdjusted,
                  onSaturationChanged: (value) =>
                      controller.setSaturation(category, value),
                  onLightnessChanged: (value) =>
                      controller.setLightness(category, value),
                  onReset: () => controller.resetAdjustment(category),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              const _SectionTitle('Finish'),
              const SizedBox(height: AppSpacing.xs),
              MakeupKitChoiceChipGroup<MakeupKitFinish>(
                options: CustomPaletteCatalog.finishesFor(category),
                selected: selection.finish,
                labelOf: (finish) => finish.label,
                onSelected: (finish) =>
                    controller.selectFinish(category, finish),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Done',
                showIcon: false,
                onPressed: () => context.pop(),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}
