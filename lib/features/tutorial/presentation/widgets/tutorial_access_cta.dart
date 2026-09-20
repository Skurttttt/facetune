import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
import '../../../results/presentation/widgets/result_shell.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../../data/providers/tutorial_providers.dart';
import '../../domain/entities/canonical_preview_ref.dart';
import '../../domain/entities/tutorial_session.dart';
import '../pages/tutorial_page.dart';
import '../utils/tutorial_labels.dart';

/// Whether a tutorial already exists for a canonical preview.
///
/// A read of the owner's own session row and nothing more — no AI work, no
/// reservation. Consulted only when the account's plan does not include the
/// Tutorial, to tell "you cannot start one" apart from "you already have one",
/// so the strip below never hides a tutorial the user made on an earlier plan.
final existingTutorialSessionProvider = FutureProvider.autoDispose
    .family<TutorialSession?, CanonicalPreviewRef>(
      (ref, preview) => ref
          .watch(tutorialSessionRepositoryProvider)
          .loadForCanonicalPreview(preview),
    );

/// The result screen's Tutorial action, aware of what the account's plan
/// includes.
///
/// Three states, all decided by server-resolved facts:
///
///   * The governing plan includes the Tutorial, or the plan is not yet known
///     → the ordinary "Show me how" action. The server authorizes again when
///     it is tapped, so an unknown plan costs nothing but a round trip.
///   * The plan is Preview-only and this look already has a tutorial → the
///     same action, because a tutorial made while it was included is
///     historical content and stays readable on every plan.
///   * The plan is Preview-only and this look has no tutorial → a notice in
///     the same strip saying so, with the plans page as the next step.
///
/// This widget reflects capability; it does not enforce it. A build that got
/// the plan wrong would show a button whose request the server refuses — and
/// the tutorial page explains that refusal in the same words.
class TutorialAccessCta extends ConsumerWidget {
  const TutorialAccessCta({
    required this.preview,
    super.key,
    this.finalPreviewUrl,
  });

  final CanonicalPreviewRef preview;
  final String? finalPreviewUrl;

  void _open(BuildContext context) => context.push(
    AppConstants.tutorialRoute,
    extra: TutorialPageArgs(preview: preview, finalPreviewUrl: finalPreviewUrl),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(
      subscriptionControllerProvider.select((state) => state.summary),
    );
    final previewOnly =
        summary != null && summary.hasEntitlement && !summary.tutorialEnabled;

    if (!previewOnly) {
      return ResultBottomCta(
        key: const ValueKey('result-primary-actions'),
        label: TutorialLabels.startTutorial,
        onPressed: () => _open(context),
      );
    }

    final existing = ref.watch(existingTutorialSessionProvider(preview));
    return existing.when(
      // A tutorial this look already has is reopened exactly as before.
      data: (session) => session != null
          ? ResultBottomCta(
              key: const ValueKey('result-primary-actions'),
              label: TutorialLabels.startTutorial,
              onPressed: () => _open(context),
            )
          : ResultBottomCta.custom(
              key: const ValueKey('result-primary-actions'),
              child: AppNotice(
                key: const ValueKey('result-tutorial-not-included'),
                title: 'Tutorial not included',
                message:
                    'Step-by-Step Tutorials are not part of '
                    '${summary.planDisplayName}. Looks you created on a plan '
                    'that includes the Tutorial keep theirs.',
                icon: Icons.auto_stories_outlined,
                tone: AppTone.info,
                actions: [
                  TertiaryButton(
                    key: const ValueKey('result-tutorial-see-plans'),
                    label: 'See plans',
                    onPressed: () =>
                        context.push(AppConstants.subscriptionRoute),
                  ),
                ],
              ),
            ),
      // While the lookup is in flight the strip is empty rather than showing
      // a button the next frame may take away. It is one owner-scoped read.
      loading: () => const SizedBox.shrink(
        key: ValueKey('result-primary-actions-pending'),
      ),
      // If the lookup fails, the server still decides: show the action and
      // let the tutorial page report the refusal, rather than deciding here
      // on an error what the plan includes.
      error: (_, _) => ResultBottomCta(
        key: const ValueKey('result-primary-actions'),
        label: TutorialLabels.startTutorial,
        onPressed: () => _open(context),
      ),
    );
  }
}
