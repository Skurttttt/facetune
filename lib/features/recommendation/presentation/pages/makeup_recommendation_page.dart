import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../makeup_styles/domain/catalog/makeup_style_catalog.dart';
import '../../../results/presentation/utils/result_formatters.dart';
import '../../../preview/presentation/controllers/makeup_preview_controller.dart';
import '../../../preview/presentation/controllers/makeup_preview_state.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/errors/recommendation_failure.dart';
import '../controllers/makeup_recommendation_controller.dart';
import '../controllers/makeup_recommendation_state.dart';
import '../widgets/recommendation_item_card.dart';

class MakeupRecommendationPage extends ConsumerWidget {
  const MakeupRecommendationPage({super.key});

  static const _labels = {
    'foundation': 'Foundation',
    'concealer': 'Concealer',
    'contour': 'Contour',
    'highlight': 'Highlight',
    'blush': 'Blush',
    'eyeshadow': 'Eyeshadow',
    'eyebrow': 'Eyebrows',
    'eyeliner': 'Eyeliner',
    'lipstick': 'Lipstick',
    'lipGloss': 'Lip gloss',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(makeupRecommendationControllerProvider);
    final previewIsGenerating = ref.watch(
      makeupPreviewControllerProvider.select(
        (state) => state.status == MakeupPreviewStatus.generating,
      ),
    );
    final paletteIsReady =
        state.status == MakeupRecommendationStatus.success &&
        state.recommendation != null;

    void generatePreview() {
      if (!paletteIsReady ||
          ref.read(makeupPreviewControllerProvider).status ==
              MakeupPreviewStatus.generating) {
        return;
      }
      ref
          .read(makeupPreviewControllerProvider.notifier)
          .generate(recommendation: state.recommendation!);
      context.push(AppConstants.previewRoute);
    }

    return Scaffold(
      appBar: const FaceTuneTopBar(title: 'Your makeup plan'),
      // The action owns layout space outside the scroll view. Scaffold measures
      // the body above it, so the last recommendation and its expanded
      // education can never sit underneath the button.
      bottomNavigationBar: paletteIsReady
          ? _PaletteBottomAction(
              previewIsGenerating: previewIsGenerating,
              onGeneratePreview: generatePreview,
            )
          : null,
      body: SafeArea(
        child: PageFrame(
          // The persistent action already provides bottom navigation and
          // gesture-area clearance. Keeping PageFrame's tail as well would
          // reserve the same space twice.
          padding: paletteIsReady
              ? PageFrame.defaultPadding.copyWith(bottom: 0)
              : PageFrame.defaultPadding,
          child: switch (state.status) {
            MakeupRecommendationStatus.generating => const Center(
              child: LoadingState(
                label: 'Designing your personalized makeup plan…',
              ),
            ),
            MakeupRecommendationStatus.failure => Center(
              child: StatusState(
                title: 'We could not create your plan',
                message: state.message ?? 'Please try again.',
                icon: Icons.error_outline_rounded,
                actionLabel:
                    state.failureType ==
                        RecommendationFailureType.authentication
                    ? 'Sign in again'
                    : state.retryable
                    ? 'Try again'
                    : null,
                onAction:
                    state.failureType ==
                        RecommendationFailureType.authentication
                    ? () => ref
                          .read(authControllerProvider.notifier)
                          .recoverExpiredSession()
                    : state.retryable
                    ? () => ref
                          .read(makeupRecommendationControllerProvider.notifier)
                          .retry()
                    : null,
                secondaryActionLabel:
                    state.failureType ==
                        RecommendationFailureType.authentication
                    ? null
                    : 'Choose another style',
                onSecondaryAction:
                    state.failureType ==
                        RecommendationFailureType.authentication
                    ? null
                    : () => context.go(AppConstants.stylesRoute),
              ),
            ),
            MakeupRecommendationStatus.success => _RecommendationContent(
              state: state,
              labels: _labels,
            ),
            MakeupRecommendationStatus.idle => Center(
              child: StatusState(
                title: 'Recommendation unavailable',
                message: 'Complete your analysis and choose a makeup style.',
                icon: Icons.info_outline_rounded,
                actionLabel: 'Return to analysis',
                onAction: () => context.go(AppConstants.analysisRoute),
              ),
            ),
          },
        ),
      ),
    );
  }
}

class _RecommendationContent extends StatefulWidget {
  const _RecommendationContent({required this.state, required this.labels});

  final MakeupRecommendationState state;
  final Map<String, String> labels;

  @override
  State<_RecommendationContent> createState() => _RecommendationContentState();
}

class _RecommendationContentState extends State<_RecommendationContent> {
  /// The one card whose education is open, keyed by its category.
  ///
  /// One value rather than a set per card, and that is the whole mechanism: a
  /// single field cannot represent two open cards, so opening one closes the
  /// previous one by construction rather than by remembering to. On a phone,
  /// three expanded explanations turn the Palette into several screens of
  /// scrolling and stop reading as one comparison.
  ///
  /// Presentation state only. It is not persisted, not derived from the
  /// recommendation, and never written back to it — tapping a card reads
  /// already-loaded data and costs nothing.
  String? _expandedCategory;

  void _toggle(String category) => setState(() {
    _expandedCategory = _expandedCategory == category ? null : category;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recommendation = widget.state.recommendation!;
    return ListView(
      children: [
        // No lead-in of its own: `PageFrame` already opens every screen with
        // the standard gap below the app bar, and adding a second one here
        // pushed the first thing worth reading further down than any other
        // screen puts it.
        //
        // The selected style is the content the user chose, so it is the
        // heading. The page already says what screen this is in the top bar;
        // repeating that as "Your personalized palette" spent the first — and
        // most valuable — line saying nothing the bar had not already said.
        Text(
          _styleName(recommendation.styleCode),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '${ResultFormatters.label(recommendation.overallIntensity)} intensity',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppColors.muted(context),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // One supporting line. The instruction that used to follow it — "tap
        // any recommendation to learn why it works for you" — described an
        // affordance every card already spells out in words.
        Text(
          'Personalized for your features.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.muted(context),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...recommendation.items.entries.expand(
          (entry) => [
            RecommendationItemCard(
              title:
                  widget.labels[entry.key] ?? ResultFormatters.label(entry.key),
              item: entry.value,
              expanded: _expandedCategory == entry.key,
              onToggle: () => _toggle(entry.key),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  /// The style's own display name, from the catalog that defines it.
  ///
  /// The recommendation carries a style *code*; title-casing that code would
  /// render "Soft glam" for a style the product calls "Soft Glam". The catalog
  /// is the authority on how a style is written, and it is a const list — this
  /// reads it, it does not select or change a style.
  ///
  /// Falls back to formatting the code for a plan whose style is no longer in
  /// the catalog, which is truthful about what the plan actually recorded
  /// rather than hiding it.
  static String _styleName(String styleCode) {
    for (final style in MakeupStyleCatalog.styles) {
      if (style.code == styleCode) return style.name;
    }
    return ResultFormatters.label(styleCode);
  }
}

/// The Palette's always-available continuation action.
///
/// This follows the established result-screen bottom-action architecture but
/// remains local because the result primitive carries result-specific keys and
/// tutorial semantics. The button itself is the global [PrimaryButton]; this
/// wrapper only reserves safe layout space and draws the standard hairline.
class _PaletteBottomAction extends StatelessWidget {
  const _PaletteBottomAction({
    required this.previewIsGenerating,
    required this.onGeneratePreview,
  });

  final bool previewIsGenerating;
  final VoidCallback onGeneratePreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.dividerTheme.color ?? theme.dividerColor,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 720),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.gutter,
                AppSpacing.sm,
              ),
              child: PrimaryButton(
                key: const ValueKey('palette-generate-preview'),
                label: previewIsGenerating
                    ? 'Creating your preview…'
                    : 'Generate makeup preview',
                icon: Icons.auto_awesome_rounded,
                onPressed: previewIsGenerating ? null : onGeneratePreview,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
