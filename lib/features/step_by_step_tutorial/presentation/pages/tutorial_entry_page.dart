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
/// This page never triggers tutorial generation or planning itself — the
/// calling page (`PreviewResultPage` / `MakeupKitRecommendationEntryPage`)
/// resolves the stable source IDs for the look already in view and calls
/// `tutorialSessionControllerProvider.notifier.load(...)` before pushing
/// this route, the same "restore ambient state, then navigate" pattern
/// already used for Saved Looks/History (see `history_page.dart`'s
/// `_open`/`_openKit`). This page only renders whatever that controller
/// reports.
///
/// A session with at least one generated step opens [TutorialStepViewer]
/// (ST-5) regardless of whether the whole session has finished — that
/// covers `loaded` (completed), `partiallyComplete`, and a `generating`
/// session that already has some steps ready, per the guide's progressive-
/// loading intent (§14). Nothing here ever fabricates step data: as of
/// ST-5 nothing in the app calls `TutorialRepository.createSession`, so in
/// practice every real visit today still lands on "Coming soon."
class TutorialEntryPage extends ConsumerWidget {
  const TutorialEntryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tutorialSessionControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('How to Apply This Look')),
      body: SafeArea(child: PageFrame(child: _content(context, ref, state))),
    );
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
          child: LoadingState(label: 'Checking for your tutorial…'),
        );
      case TutorialSessionStatus.loaded:
        if (hasViewableSteps) return TutorialStepViewer(session: session);
        return Center(
          child: session == null
              ? StatusState(
                  title: 'Coming soon',
                  message:
                      'Step-by-step tutorials for this look are not '
                      'available yet. We are working on it.',
                  icon: Icons.auto_stories_outlined,
                  actionLabel: 'Return',
                  onAction: () => context.pop(),
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
        if (hasViewableSteps) return TutorialStepViewer(session: session);
        return _inProgress(context, ref);
      case TutorialSessionStatus.generating:
        if (hasViewableSteps) return TutorialStepViewer(session: session);
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
