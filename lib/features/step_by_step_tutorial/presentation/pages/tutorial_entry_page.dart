import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../controllers/tutorial_session_controller.dart';
import '../controllers/tutorial_session_state.dart';
import '../widgets/tutorial_step_viewer.dart';

/// Landing page for "How to Apply This Look".
///
/// This page never *decides* to create or generate anything itself — the
/// calling page (`PreviewResultPage` / `MakeupKitRecommendationEntryPage`)
/// calls `tutorialSessionControllerProvider.notifier.prepareForRecommendation`/
/// `prepareForKitRecommendation` (which only checks for an existing
/// session) before pushing this route, the same "restore ambient state,
/// then navigate" pattern already used for Saved Looks/History (see
/// `history_page.dart`'s `_open`/`_openKit`). Creating a new session (ST-8)
/// only ever happens from the explicit "Generate my tutorial" tap below —
/// never automatically on navigation or on a background refresh.
///
/// A session with at least one generated step opens [TutorialStepViewer]
/// regardless of whether the whole session has finished — that covers
/// `loaded` (completed), `partiallyComplete`, and a `generating` session
/// that already has some steps ready, per the guide's progressive-loading
/// intent (§14).
class TutorialEntryPage extends ConsumerWidget {
  const TutorialEntryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tutorialSessionControllerProvider);
    final session = state.session;
    final canRegenerate =
        session != null &&
        session.steps.isNotEmpty &&
        state.status != TutorialSessionStatus.loading &&
        state.generatingStepId == null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('How to Apply This Look'),
        actions: [
          if (session != null && session.steps.isNotEmpty)
            IconButton(
              tooltip: 'Regenerate tutorial',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: canRegenerate
                  ? () => _confirmRegenerate(context, ref)
                  : null,
            ),
        ],
      ),
      body: SafeArea(child: PageFrame(child: _content(context, ref, state))),
    );
  }

  /// Regeneration clears every non-final step's generated image and
  /// returns it to `not_started` (`TutorialRepository.resetForRegeneration`)
  /// rather than creating a second session — see ARCHITECTURE_NOTES.md's
  /// ST-12 section for why a genuinely separate "new version" isn't
  /// possible without first generating a new source-look variation.
  /// Communicates both required facts (roadmap ST-12 task 4) before
  /// anything happens: regenerating needs fresh AI generation, and
  /// cancelling leaves the existing tutorial exactly as it is — matching
  /// the `AlertDialog`/Cancel-then-primary-action convention already used
  /// by `saved_looks_page.dart`/`history_page.dart`'s confirmations.
  Future<void> _confirmRegenerate(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Regenerate this tutorial?'),
        content: const Text(
          "Every step's generated image will be cleared so you can create "
          'new ones — each will need a fresh AI generation the next time '
          'you view it. Your written instructions stay the same. If you '
          'cancel, your current tutorial keeps working exactly as it is '
          'now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(tutorialSessionControllerProvider.notifier).regenerate();
    }
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    TutorialSessionState state,
  ) {
    final session = state.session;
    final hasViewableSteps = session != null && session.steps.isNotEmpty;
    switch (state.status) {
      case TutorialSessionStatus.initial:
        return Center(
          child: StatusState(
            title: 'Tutorial unavailable',
            message:
                'We could not identify which look to build a tutorial for.',
            icon: Icons.link_off_rounded,
            actionLabel: 'Return',
            onAction: () => context.pop(),
          ),
        );
      case TutorialSessionStatus.loading:
        return const Center(
          child: LoadingState(label: 'Preparing your tutorial…'),
        );
      case TutorialSessionStatus.loaded:
        if (hasViewableSteps) return TutorialStepViewer(state: state);
        return Center(
          child: session == null
              ? StatusState(
                  title: 'Ready to build your tutorial',
                  message:
                      'Create a step-by-step guide to recreate this look '
                      'on your own face.',
                  icon: Icons.auto_stories_outlined,
                  actionLabel: 'Generate my tutorial',
                  onAction: () => ref
                      .read(tutorialSessionControllerProvider.notifier)
                      .generate(),
                  secondaryActionLabel: 'Return',
                  onSecondaryAction: () => context.pop(),
                )
              : StatusState(
                  title: 'No steps yet',
                  message:
                      'This tutorial does not have any generated steps to '
                      'show yet.',
                  icon: Icons.auto_stories_outlined,
                  actionLabel: 'Return',
                  onAction: () => context.pop(),
                ),
        );
      case TutorialSessionStatus.partiallyComplete:
        if (hasViewableSteps) return TutorialStepViewer(state: state);
        return _inProgress(context, ref);
      case TutorialSessionStatus.generating:
        if (hasViewableSteps) return TutorialStepViewer(state: state);
        return _inProgress(context, ref);
      case TutorialSessionStatus.failed:
        return Center(
          child: StatusState(
            title: 'Tutorial unavailable',
            message: state.message ?? 'Please try again.',
            icon: Icons.error_outline_rounded,
            actionLabel: state.sessionExpired
                ? 'Sign in again'
                : state.retryable
                ? 'Try again'
                : null,
            onAction: state.sessionExpired
                ? () => ref
                      .read(authControllerProvider.notifier)
                      .recoverExpiredSession()
                : state.retryable
                ? () => ref
                      .read(tutorialSessionControllerProvider.notifier)
                      .retry()
                : null,
            secondaryActionLabel: 'Return',
            onSecondaryAction: () => context.pop(),
          ),
        );
    }
  }

  Widget _inProgress(BuildContext context, WidgetRef ref) => Center(
    child: StatusState(
      title: 'Tutorial in progress',
      message:
          'Your step-by-step tutorial is still being generated. Check '
          'back soon.',
      icon: Icons.hourglass_top_rounded,
      actionLabel: 'Check again',
      onAction: () =>
          ref.read(tutorialSessionControllerProvider.notifier).retry(),
      secondaryActionLabel: 'Return',
      onSecondaryAction: () => context.pop(),
    ),
  );
}
