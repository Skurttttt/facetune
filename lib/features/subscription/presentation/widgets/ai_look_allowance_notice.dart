import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';
import '../controllers/subscription_controller.dart';
import '../utils/ai_look_allowance_copy.dart';

/// A reminder of how many AI Looks are left, for the moment just before the
/// user spends one.
///
/// Deliberately non-blocking. It never disables the Generate action: the server
/// decides whether a generation may proceed and returns a sanitized refusal if
/// not, so a stale "0 remaining" here must not be able to lock a user out of an
/// allowance they actually have. This informs; it does not gate.
///
/// Renders nothing until the server has answered — an invented count is worse
/// than none, because the user would act on it.
///
/// Two treatments, chosen by how much the message matters:
///
///   * comfortable capacity — a quiet muted line, drawn straight on the page
///     background, that does not compete with the primary action;
///   * the last look, or an exhausted or blocked entitlement — an [AppNotice],
///     which brings its own tinted surface and a contrast pairing guaranteed
///     for it. The tinted role colours are only safe on that surface, which is
///     why they are not painted onto the bare page for the quiet case.
class AiLookAllowanceNotice extends ConsumerWidget {
  const AiLookAllowanceNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionControllerProvider);
    final copy = AiLookAllowanceCopy.forState(state);
    if (copy == null) return const SizedBox.shrink();

    final emphasised = copy.headline != null || copy.tone != AppTone.info;

    if (emphasised) {
      return Padding(
        key: const ValueKey('ai-look-allowance-notice'),
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: AppNotice(
          title: copy.headline,
          message: copy.headline == null
              ? copy.compactLine
              : (copy.detail ?? copy.remainingLine),
          tone: copy.tone,
        ),
      );
    }

    return Padding(
      key: const ValueKey('ai-look-allowance-notice'),
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        copy.compactLine,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.muted(context)),
      ),
    );
  }
}
