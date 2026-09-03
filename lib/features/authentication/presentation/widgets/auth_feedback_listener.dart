import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
import '../controllers/auth_controller.dart';
import '../controllers/auth_state.dart';

/// Surfaces one auth message per state change.
///
/// Which message is shown, and when, is unchanged: the controller still decides
/// by bumping `feedbackId`, and an error still takes precedence over a notice.
/// What is new is that the two no longer look identical — a failed sign-in and
/// a "check your email" confirmation were both plain grey bars, so the only way
/// to tell them apart was to read carefully.
void listenForAuthFeedback(WidgetRef ref, BuildContext context) {
  ref.listen<AuthState>(authControllerProvider, (previous, next) {
    if (previous?.feedbackId == next.feedbackId) {
      return;
    }
    final message = next.errorMessage ?? next.notice;
    if (message == null || !context.mounted) {
      return;
    }
    showAppSnackBar(
      context,
      message: message,
      // The controller has already decided which of the two this is; the tone
      // reads that decision rather than re-deriving it from the text.
      tone: next.errorMessage != null ? AppTone.danger : AppTone.info,
    );
  });
}
