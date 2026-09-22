import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/subscription/domain/entities/billing_provider.dart';
import '../../../../features/subscription/domain/entities/subscription_plan_code.dart';
import '../../../../theme/app_tokens.dart';
import '../../../app/admin_routes.dart';
import '../../../shared/admin_labels.dart';
import '../../../shared/admin_list_widgets.dart';
import '../../../users/domain/admin_user_models.dart';
import '../../../users/presentation/admin_users_controller.dart';
import '../../domain/admin_salon_pilot_models.dart';
import '../admin_adjust_allowance_controller.dart';

/// Adjust a Salon Pilot allowance: quick +5 / +10 or a custom signed amount,
/// a required reason, an informational preview, confirm, and the server's
/// authoritative new state. The current figures come from the user detail
/// read (WA-5); the change is applied only by the audited server writer.
class AdminAdjustAllowancePage extends ConsumerStatefulWidget {
  const AdminAdjustAllowancePage({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<AdminAdjustAllowancePage> createState() =>
      _AdminAdjustAllowancePageState();
}

class _AdminAdjustAllowancePageState
    extends ConsumerState<AdminAdjustAllowancePage> {
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  String? _amountError;
  String? _reasonError;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  /// The signed amount typed or chosen. Null when empty or not an integer.
  static int? parseAmount(String text) {
    final trimmed = text.trim().replaceFirst(RegExp(r'^\+'), '');
    return RegExp(r'^-?\d+$').hasMatch(trimmed) ? int.tryParse(trimmed) : null;
  }

  void _preview(AdminEntitlementDetail entitlement) {
    final amount = parseAmount(_amount.text);
    final reason = _reason.text.trim();
    final amountError = amount == null
        ? 'Enter a whole number, e.g. 10 or -5.'
        : amount == 0
        ? 'The adjustment cannot be zero.'
        : null;
    final reasonError = reason.isEmpty
        ? 'A reason is required.'
        : reason.length > adminReasonMaxLength
        ? 'Keep the reason under $adminReasonMaxLength characters.'
        : null;
    setState(() {
      _amountError = amountError;
      _reasonError = reasonError;
    });
    if (amountError != null || reasonError != null) return;
    ref
        .read(
          adminAdjustAllowanceControllerProvider(
            entitlement.entitlementId,
          ).notifier,
        )
        .preview(
          amount: amount!,
          reason: reason,
          currentEffectiveAllowance: entitlement.effectiveAllowance,
          committedUsage: entitlement.committedUsage,
          reservedUsage: entitlement.reservedUsage,
          expectedVersion: entitlement.version,
        );
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(adminUserDetailControllerProvider(widget.userId));
    final theme = Theme.of(context);

    return Column(
      key: const Key('admin-adjust-allowance'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          key: const Key('admin-adjust-back'),
          onPressed: () => context.go(AdminRoutes.userDetail(widget.userId)),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back to user'),
        ),
        const SizedBox(height: AppSpacing.xs),
        const AdminSectionHeading(
          title: 'Adjust Salon Pilot allowance',
          description:
              'Adds to or reduces the AI Look allowance through the audited '
              'adjustment ledger. Committed usage is never changed; a '
              'reduction must keep committed and reserved usage covered.',
        ),
        const SizedBox(height: AppSpacing.lg),
        switch (detail) {
          AdminUserDetailLoading() => const AdminListLoadingRow(
            key: Key('admin-adjust-loading'),
            label: 'Loading entitlement',
          ),
          AdminUserDetailNotFound() => const AdminListNotice(
            key: Key('admin-adjust-not-found'),
            icon: Icons.info_outline,
            message: 'User not found.',
          ),
          AdminUserDetailUnavailable() => const AdminListNotice(
            key: Key('admin-adjust-unavailable'),
            icon: Icons.error_outline,
            message: 'The entitlement could not be loaded.',
          ),
          AdminUserDetailReady(:final detail) => _body(detail, theme),
        },
      ],
    );
  }

  Widget _body(AdminUserDetail detail, ThemeData theme) {
    final entitlement = detail.entitlement;
    if (entitlement == null ||
        entitlement.planCode != SubscriptionPlanCode.salonPilot ||
        entitlement.billingProvider != BillingProvider.adminGranted) {
      return const AdminListNotice(
        key: Key('admin-adjust-not-editable'),
        icon: Icons.info_outline,
        message:
            'This account has no admin-granted Salon Pilot entitlement in '
            'force. Only a Salon Pilot allowance can be adjusted.',
      );
    }
    final state = ref.watch(
      adminAdjustAllowanceControllerProvider(entitlement.entitlementId),
    );
    final controller = ref.read(
      adminAdjustAllowanceControllerProvider(
        entitlement.entitlementId,
      ).notifier,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CurrentFigures(detail: detail, entitlement: entitlement),
        const SizedBox(height: AppSpacing.lg),
        switch (state) {
          AdminAdjustEditing() => _form(entitlement),
          AdminAdjustPreviewing(:final intent, :final preview) => _Preview(
            intent: intent,
            preview: preview,
            onEdit: controller.edit,
            onConfirm: controller.confirm,
          ),
          AdminAdjustSubmitting() => const AdminListLoadingRow(
            key: Key('admin-adjust-submitting'),
            label: 'Applying adjustment',
          ),
          AdminAdjustSucceeded(:final intent, :final outcome) => _Result(
            intent: intent,
            outcome: outcome,
            userId: widget.userId,
            onAnother: () {
              controller.edit();
              ref
                  .read(
                    adminUserDetailControllerProvider(widget.userId).notifier,
                  )
                  .load();
            },
          ),
          AdminAdjustFailed(:final failure) => _Failure(
            failure: failure,
            onRetry: controller.confirm,
            onEdit: () {
              controller.edit();
              // A stale-version or reduction refusal means the figures moved;
              // reload them before the admin tries again.
              ref
                  .read(
                    adminUserDetailControllerProvider(widget.userId).notifier,
                  )
                  .load();
            },
          ),
        },
      ],
    );
  }

  Widget _form(AdminEntitlementDetail entitlement) {
    return ConstrainedBox(
      key: const Key('admin-adjust-form'),
      constraints: const BoxConstraints(maxWidth: 640),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final quick in salonPilotQuickAdjustments)
                OutlinedButton(
                  key: Key('admin-adjust-quick-$quick'),
                  onPressed: () => setState(() {
                    _amount.text = '$quick';
                    _amountError = null;
                  }),
                  child: Text('+$quick'),
                ),
              const Text('or a custom amount:'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('admin-adjust-amount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            decoration: InputDecoration(
              labelText: 'Adjustment (AI Looks)',
              helperText:
                  'Positive adds, negative reduces. A reduction cannot go '
                  'below committed usage or currently reserved AI Looks.',
              errorText: _amountError,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('admin-adjust-reason'),
            controller: _reason,
            maxLines: 3,
            maxLength: adminReasonMaxLength,
            decoration: InputDecoration(
              labelText: 'Reason',
              helperText:
                  'Required, e.g. "Panel testing extension" or "Administrative correction".',
              errorText: _reasonError,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('admin-adjust-preview'),
            onPressed: () => _preview(entitlement),
            icon: const Icon(Icons.preview_outlined, size: 18),
            label: const Text('Preview adjustment'),
          ),
        ],
      ),
    );
  }
}

class _CurrentFigures extends StatelessWidget {
  const _CurrentFigures({required this.detail, required this.entitlement});

  final AdminUserDetail detail;
  final AdminEntitlementDetail entitlement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      key: const Key('admin-adjust-current'),
      constraints: const BoxConstraints(maxWidth: 640),
      child: _Panel(
        title: 'Current (server)',
        rows: [
          ('Account', detail.email ?? detail.userId),
          ('Entitlement ID', entitlement.entitlementId),
          ('Status', entitlementStatusLabel(entitlement.effectiveStatus)),
          ('Effective allowance', '${entitlement.effectiveAllowance}'),
          ('Committed', '${entitlement.committedUsage}'),
          ('Reserved', '${entitlement.reservedUsage}'),
          ('Remaining', '${entitlement.remainingAiLooks}'),
          ('Available for a new generation', '${entitlement.availableAiLooks}'),
          ('Version', '${entitlement.version}'),
        ],
        theme: theme,
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.intent,
    required this.preview,
    required this.onEdit,
    required this.onConfirm,
  });

  final AdjustAllowanceIntent intent;
  final AllowanceAdjustmentPreview preview;
  final VoidCallback onEdit;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warning = !preview.coversCommittedUsage
        ? 'This would put the allowance below committed usage. The server '
              'will refuse it.'
        : !preview.coversReservations
        ? 'This would not cover an AI Look that is currently reserved. The '
              'server will refuse it while the reservation is held.'
        : null;
    return ConstrainedBox(
      key: const Key('admin-adjust-preview-panel'),
      constraints: const BoxConstraints(maxWidth: 640),
      child: _Panel(
        title: 'Review before applying',
        theme: theme,
        rows: [
          (
            'Current effective allowance',
            '${preview.currentEffectiveAllowance}',
          ),
          ('Adjustment', _signed(intent.amount)),
          ('New effective allowance', '${preview.newEffectiveAllowance}'),
          ('Committed', '${preview.committedUsage}'),
          ('Reserved', '${preview.reservedUsage}'),
          ('New remaining', '${preview.newRemaining}'),
          ('New available', '${preview.newAvailable}'),
          ('Reason', intent.reason),
          ('Based on version', '${intent.expectedVersion ?? 'not checked'}'),
        ],
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (warning != null) ...[
              Text(
                warning,
                key: const Key('admin-adjust-preview-warning'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(
              'The preview is informational. The server recomputes every '
              'figure under the account lock, refuses an unsafe reduction, '
              'and records one audit event under your admin identity. A '
              'duplicate submission applies once.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                FilledButton.icon(
                  key: const Key('admin-adjust-confirm'),
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(
                    intent.isIncrease
                        ? 'Confirm increase'
                        : 'Confirm reduction',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  key: const Key('admin-adjust-edit'),
                  onPressed: onEdit,
                  child: const Text('Edit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.intent,
    required this.outcome,
    required this.userId,
    required this.onAnother,
  });

  final AdjustAllowanceIntent intent;
  final AdminMutationOutcome outcome;
  final String userId;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      key: const Key('admin-adjust-succeeded'),
      constraints: const BoxConstraints(maxWidth: 640),
      child: _Panel(
        title: outcome.replayed
            ? 'This adjustment was already applied by this request'
            : 'Allowance adjusted (${_signed(intent.amount)})',
        theme: theme,
        highlighted: true,
        rows: [
          ('Effective allowance', '${outcome.effectiveAllowance}'),
          ('Committed', '${outcome.committedUsage}'),
          ('Reserved', '${outcome.reservedUsage}'),
          ('Remaining', '${outcome.remainingAiLooks}'),
          ('Available for a new generation', '${outcome.availableAiLooks}'),
          ('Status', entitlementStatusLabel(outcome.status)),
          ('Updated', formatUtcDateTime(outcome.updatedAt)),
        ],
        footer: Row(
          children: [
            FilledButton(
              key: const Key('admin-adjust-done'),
              onPressed: () => context.go(AdminRoutes.userDetail(userId)),
              child: const Text('Back to user'),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              key: const Key('admin-adjust-another'),
              onPressed: onAnother,
              child: const Text('Make another adjustment'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({
    required this.failure,
    required this.onRetry,
    required this.onEdit,
  });

  final AdminMutationFailure failure;
  final Future<void> Function() onRetry;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: const Key('admin-adjust-failed'),
      constraints: const BoxConstraints(maxWidth: 640),
      child: AdminListNotice(
        icon: Icons.error_outline,
        message:
            '${failure.message ?? _fallback(failure.code)} (${failure.code.code})',
        action: failure.retryable
            ? TextButton(
                key: const Key('admin-adjust-retry'),
                onPressed: onRetry,
                child: const Text('Try again'),
              )
            : TextButton(
                key: const Key('admin-adjust-start-over'),
                onPressed: onEdit,
                child: const Text('Reload and edit'),
              ),
      ),
    );
  }

  static String _fallback(AdminMutationErrorCode code) => switch (code) {
    AdminMutationErrorCode.allowanceBelowCommittedUsage =>
      'That reduction would put the allowance below committed usage.',
    AdminMutationErrorCode.allowanceConflictsWithActiveReservation =>
      'That reduction would not cover a currently reserved AI Look.',
    AdminMutationErrorCode.concurrentModification =>
      'The entitlement changed while you were working.',
    AdminMutationErrorCode.invalidAllowanceAdjustment =>
      'Only an admin-granted Salon Pilot allowance can be adjusted.',
    AdminMutationErrorCode.entitlementNotFound => 'No entitlement matches.',
    AdminMutationErrorCode.entitlementExpired =>
      'This entitlement has ended and cannot be adjusted.',
    AdminMutationErrorCode.entitlementRevoked =>
      'This entitlement was revoked and cannot be adjusted.',
    AdminMutationErrorCode.idempotencyConflict =>
      'This request was already submitted with different values.',
    _ => 'The adjustment could not be completed.',
  };
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.rows,
    required this.theme,
    this.footer,
    this.highlighted = false,
  });

  final String title;
  final List<(String, String)> rows;
  final ThemeData theme;
  final Widget? footer;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(
        color: highlighted
            ? theme.colorScheme.primary
            : theme.colorScheme.outlineVariant,
      ),
      borderRadius: BorderRadius.circular(AppRadii.sm),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 240,
                    child: Text(row.$1, style: theme.textTheme.labelMedium),
                  ),
                  Expanded(
                    child: SelectableText(
                      row.$2,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.sm),
            footer!,
          ],
        ],
      ),
    ),
  );
}

String _signed(int value) => value > 0 ? '+$value' : '$value';
