import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';
import '../../../makeup_kit/presentation/utils/makeup_kit_display.dart';
import '../controllers/custom_palette_draft_controller.dart';
import '../controllers/custom_palette_draft_state.dart';
import '../widgets/custom_palette_not_ready_state.dart';
import '../widgets/custom_palette_selection_summary.dart';

/// The last check before generating: what will be used, and the chance to
/// change it. Generate stays disabled unless the palette contract passes.
class CustomPaletteReviewPage extends ConsumerWidget {
  const CustomPaletteReviewPage({super.key});

  static const _title = 'Review palette';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(customPaletteDraftControllerProvider);
    if (draft.analysisId == null) {
      return const CustomPaletteNotReadyState(title: _title);
    }
    final message = draft.message;
    return Scaffold(
      appBar: const FaceTuneTopBar(title: _title),
      body: SafeArea(
        child: PageFrame(
          child: ListView(
            children: [
              for (final category in draft.enabledCategories) ...[
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomPaletteSelectionSummary(
                        title: category.label,
                        selection: draft.selectionFor(category),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TertiaryButton(
                          label: 'Edit ${category.label}',
                          onPressed: draft.isSubmitting
                              ? null
                              : () => context.push(
                                  AppConstants.customPaletteCategoryLocation(
                                    category.code,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(
                'Your colors and finishes stay as you chose them. FaceTune '
                'decides placement and technique. Colors can look slightly '
                'different in your photo’s lighting.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted(context),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (message != null) ...[
                AppNotice(
                  message: message,
                  tone: AppTone.danger,
                  liveRegion: true,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              PrimaryButton(
                label: 'Generate my look',
                icon: Icons.auto_awesome_rounded,
                isLoading: draft.isSubmitting,
                onPressed: _canGenerate(draft)
                    ? () => ref
                          .read(customPaletteDraftControllerProvider.notifier)
                          .generate()
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  bool _canGenerate(CustomPaletteDraftState draft) =>
      draft.isValid &&
      !draft.isSubmitting &&
      draft.status != CustomPaletteDraftStatus.submitted;
}
