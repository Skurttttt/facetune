import 'package:flutter/material.dart';

import '../../../theme/app_semantics.dart';
import '../../../theme/app_tokens.dart';

/// Asks the user to confirm before something happens.
///
/// Returns true only on an explicit confirm. A dismissal — barrier tap, back
/// gesture, Cancel — returns null or false, never true, so a caller that writes
/// `if (await showConfirmationDialog(...) == true)` cannot act on a user who
/// simply walked away.
///
/// [isDestructive] is not decoration. FaceTune has confirmations that
/// permanently delete a history session and its stored images, and those must
/// not look like "Continue?". It tints the confirm button with the danger role
/// and defaults the label to something that names the act.
Future<bool?> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  String cancelLabel = 'Cancel',
  String? confirmLabel,
  bool isDestructive = false,
}) => showDialog<bool>(
  context: context,
  builder: (context) {
    final danger = AppTone.danger.resolve(context);
    return AlertDialog(
      icon: isDestructive
          ? Icon(Icons.warning_amber_rounded, color: danger.accent)
          : null,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: danger.feedbackSurface,
                  foregroundColor: danger.onFeedbackSurface,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel ?? (isDestructive ? 'Delete' : 'Confirm')),
        ),
      ],
    );
  },
);

/// A modal sheet carrying the app's own padding and shape.
///
/// `isScrollControlled` is on so a tall sheet can grow past half the screen
/// rather than clipping its own content, and `useSafeArea` keeps it clear of
/// the gesture bar.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required Widget child,
}) => showModalBottomSheet<T>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.xs,
      AppSpacing.lg,
      AppSpacing.xl,
    ),
    child: child,
  ),
);

/// Transient feedback: the app confirming, or reporting, something that just
/// happened.
///
/// This is the success/error feedback component the app did not have. Of 29
/// snackbars, 5 set a background colour and 24 set none, so a failure and a
/// confirmation looked identical unless the call site happened to remember.
/// Routing them through one function makes the tone a required thought rather
/// than an optional flourish.
///
/// Hides any current snackbar first. Without that, two messages in quick
/// succession queue up and the user reads the stale one — several call sites
/// had already discovered this and were calling `hideCurrentSnackBar` by hand.
///
/// This function only presents; it starts no work and reads no provider, so it
/// is safe to call from a listener without risking a repeated action.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppSnackBar(
  BuildContext context, {
  required String message,
  AppTone tone = AppTone.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final role = tone.resolve(context);
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      backgroundColor: role.feedbackSurface,
      content: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: role.onFeedbackSurface),
      ),
      // A failure the user has to read and act on gets longer than a
      // confirmation they can ignore.
      duration: tone == AppTone.danger
          ? const Duration(seconds: 8)
          : const Duration(seconds: 4),
      action: actionLabel == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              textColor: role.onFeedbackSurface,
              onPressed: onAction ?? () {},
            ),
    ),
  );
}
