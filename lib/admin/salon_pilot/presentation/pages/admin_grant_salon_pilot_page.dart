import '../../../shared/admin_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/admin_dialogs.dart';
import '../../../shared/admin_form_widgets.dart';
import '../../../theme/admin_tokens.dart';
import '../../../app/admin_routes.dart';
import '../../../shared/admin_labels.dart';
import '../../../shared/admin_list_widgets.dart';
import '../../../users/presentation/admin_users_controller.dart';
import '../../domain/admin_salon_pilot_models.dart';
import '../admin_grant_salon_pilot_controller.dart';

/// Grant a Salon Pilot entitlement to one account:
/// form → preview → confirm → the server's authoritative new state.
class AdminGrantSalonPilotPage extends ConsumerStatefulWidget {
  const AdminGrantSalonPilotPage({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<AdminGrantSalonPilotPage> createState() =>
      _AdminGrantSalonPilotPageState();
}

class _AdminGrantSalonPilotPageState
    extends ConsumerState<AdminGrantSalonPilotPage> {
  final _expiration = TextEditingController();
  final _allowance = TextEditingController(
    text: '$salonPilotDefaultInitialAllowance',
  );
  final _reason = TextEditingController();
  String? _expirationError;
  String? _allowanceError;
  String? _reasonError;

  @override
  void dispose() {
    _expiration.dispose();
    _allowance.dispose();
    _reason.dispose();
    super.dispose();
  }

  AdminGrantSalonPilotController get _controller =>
      ref.read(adminGrantSalonPilotControllerProvider(widget.userId).notifier);

  /// The expiration date the admin typed or picked, as the end of that UTC
  /// day. Null when the field is empty or not a date.
  static DateTime? parseExpiration(String text) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text.trim());
    if (match == null) return null;
    final day = DateTime.tryParse('${match[0]}T00:00:00Z');
    if (day == null) return null;
    return DateTime.utc(day.year, day.month, day.day, 23, 59, 59);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now().toUtc();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          parseExpiration(_expiration.text) ??
          now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
      helpText: 'Salon Pilot expiration (UTC)',
    );
    if (picked == null) return;
    setState(() {
      _expiration.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      _expirationError = null;
    });
  }

  Future<void> _preview(String? email) async {
    final expiresAt = parseExpiration(_expiration.text);
    final allowance = int.tryParse(_allowance.text.trim());
    final reason = _reason.text.trim();
    final expirationError = expiresAt == null
        ? 'Enter an expiration date as YYYY-MM-DD.'
        : !expiresAt.isAfter(DateTime.now().toUtc())
        ? 'The expiration must be in the future.'
        : null;
    final allowanceError = allowance == null || allowance < 0
        ? 'Enter a whole number of 0 or more.'
        : null;
    final reasonError = reason.isEmpty
        ? 'A reason is required.'
        : reason.length > adminReasonMaxLength
        ? 'Keep the reason under $adminReasonMaxLength characters.'
        : null;
    setState(() {
      _expirationError = expirationError;
      _allowanceError = allowanceError;
      _reasonError = reasonError;
    });
    if (expirationError != null ||
        allowanceError != null ||
        reasonError != null) {
      return;
    }
    _controller.preview(
      expiresAt: expiresAt!,
      initialAllowance: allowance!,
      reason: reason,
    );
    final state = ref.read(
      adminGrantSalonPilotControllerProvider(widget.userId),
    );
    if (state is! AdminGrantPreviewing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _Preview(
        intent: state.intent,
        email: email,
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      await _controller.confirm();
    } else {
      _controller.edit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      adminGrantSalonPilotControllerProvider(widget.userId),
    );
    final detail = ref.watch(adminUserDetailControllerProvider(widget.userId));
    final theme = Theme.of(context);
    final email = switch (detail) {
      AdminUserDetailReady(:final detail) => detail.email,
      _ => null,
    };

    return Column(
      key: const Key('admin-grant-salon-pilot'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          key: const Key('admin-grant-back'),
          onPressed: () => context.go(AdminRoutes.userDetail(widget.userId)),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back to user'),
        ),
        const SizedBox(height: AdminSpacing.xs),
        const AdminPageHeader(
          title: 'Grant Salon Pilot',
          subtitle:
              'A complimentary, temporary, admin-granted entitlement with a '
              'pool of AI Looks. It is recorded as admin_granted, never as a '
              'store purchase, and is audited with your identity and reason.',
        ),
        const SizedBox(height: AdminSpacing.sm),
        Text(
          'Target account: ${email ?? 'loading…'}',
          style: theme.textTheme.bodyMedium,
        ),
        SelectableText(
          widget.userId,
          style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
        ),
        const SizedBox(height: AdminSpacing.lg),
        switch (state) {
          AdminGrantEditing() => _form(email),
          AdminGrantPreviewing() => const SizedBox.shrink(),
          AdminGrantSubmitting() => const AdminListLoadingRow(
            key: Key('admin-grant-submitting'),
            label: 'Granting Salon Pilot',
            skeleton: false,
          ),
          AdminGrantSucceeded(:final outcome) => _Result(
            outcome: outcome,
            userId: widget.userId,
          ),
          AdminGrantFailed(:final failure) => _Failure(
            failure: failure,
            onRetry: _controller.confirm,
            onEdit: _controller.edit,
          ),
        },
      ],
    );
  }

  Widget _form(String? email) {
    return ConstrainedBox(
      key: const Key('admin-grant-form'),
      constraints: const BoxConstraints(maxWidth: 640),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminLabeledField(
            label: 'Expiration date (UTC)',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('admin-grant-expiration'),
                    controller: _expiration,
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      helperText:
                          'YYYY-MM-DD. The grant ends at the end of that day. Required.',
                      errorText: _expirationError,
                    ),
                  ),
                ),
                const SizedBox(width: AdminSpacing.sm),
                OutlinedButton.icon(
                  key: const Key('admin-grant-pick-date'),
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: const Text('Pick date'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AdminSpacing.md),
          AdminLabeledField(
            label: 'Initial AI Look allowance',
            child: TextField(
              key: const Key('admin-grant-allowance'),
              controller: _allowance,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                helperText:
                    'Default $salonPilotDefaultInitialAllowance. The server validates the submitted value.',
                errorText: _allowanceError,
              ),
            ),
          ),
          const SizedBox(height: AdminSpacing.md),
          AdminLabeledField(
            label: 'Reason',
            child: TextField(
              key: const Key('admin-grant-reason'),
              controller: _reason,
              maxLines: 3,
              maxLength: adminReasonMaxLength,
              decoration: InputDecoration(
                helperText:
                    'Required. Operational and privacy-conscious, e.g. "Panel research cohort A".',
                errorText: _reasonError,
              ),
            ),
          ),
          const SizedBox(height: AdminSpacing.lg),
          FilledButton.icon(
            key: const Key('admin-grant-preview'),
            onPressed: () => _preview(email),
            icon: const Icon(Icons.preview_outlined, size: 18),
            label: const Text('Preview grant'),
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.intent,
    required this.email,
    required this.onCancel,
    required this.onConfirm,
  });

  final GrantSalonPilotIntent intent;
  final String? email;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminConfirmationDialog(
      key: const Key('admin-grant-preview-panel'),
      title: 'Review before granting',
      description:
          'Confirm the target account and the temporary Salon Pilot terms.',
      confirmLabel: 'Confirm grant',
      confirmButtonKey: const Key('admin-grant-confirm'),
      cancelButtonKey: const Key('admin-grant-edit'),
      onConfirm: onConfirm,
      onCancel: onCancel,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminDialogDetailRows(
            rows: [
              ('Account', email ?? intent.targetUserId),
              ('Plan', 'Salon Pilot (salon_pilot)'),
              ('Billing provider', 'Admin Granted (admin_granted)'),
              ('Initial AI Look allowance', '${intent.initialAllowance}'),
              ('Expires', formatUtcDateTime(intent.expiresAt)),
              ('Auto-renew', 'Off'),
              ('Reason', intent.reason),
            ],
          ),
          const SizedBox(height: AdminSpacing.md),
          Text(
            'Confirming writes the entitlement and one audit event under '
            'your admin identity. A duplicate submission replays this grant; '
            'it never creates a second one.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  static Widget _row(ThemeData theme, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AdminSpacing.xxs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 220,
          child: Text(label, style: theme.textTheme.labelMedium),
        ),
        Expanded(
          child: SelectableText(value, style: theme.textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

class _Result extends StatelessWidget {
  const _Result({required this.outcome, required this.userId});

  final AdminMutationOutcome outcome;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      key: const Key('admin-grant-succeeded'),
      constraints: const BoxConstraints(maxWidth: 640),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.primary),
          borderRadius: BorderRadius.circular(AdminRadii.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AdminSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  outcome.replayed
                      ? 'Salon Pilot was already granted by this request'
                      : 'Salon Pilot granted',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: AdminSpacing.sm),
              _Preview._row(theme, 'Entitlement ID', outcome.entitlementId),
              _Preview._row(theme, 'Plan', planCodeLabel(outcome.planCode)),
              _Preview._row(
                theme,
                'Status',
                entitlementStatusLabel(outcome.status),
              ),
              _Preview._row(
                theme,
                'Effective allowance',
                '${outcome.effectiveAllowance}',
              ),
              _Preview._row(theme, 'Committed', '${outcome.committedUsage}'),
              _Preview._row(theme, 'Reserved', '${outcome.reservedUsage}'),
              _Preview._row(theme, 'Remaining', '${outcome.remainingAiLooks}'),
              _Preview._row(
                theme,
                'Available for a new generation',
                '${outcome.availableAiLooks}',
              ),
              _Preview._row(
                theme,
                'Expires',
                outcome.expiresAt == null
                    ? 'Not applicable'
                    : formatUtcDateTime(outcome.expiresAt!),
              ),
              _Preview._row(
                theme,
                'Updated',
                formatUtcDateTime(outcome.updatedAt),
              ),
              const SizedBox(height: AdminSpacing.md),
              Row(
                children: [
                  FilledButton(
                    key: const Key('admin-grant-done'),
                    onPressed: () => context.go(AdminRoutes.userDetail(userId)),
                    child: const Text('Back to user'),
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  TextButton(
                    key: const Key('admin-grant-view-usage'),
                    onPressed: () =>
                        context.go(AdminRoutes.usageForUser(userId)),
                    child: const Text('View usage'),
                  ),
                ],
              ),
            ],
          ),
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
      key: const Key('admin-grant-failed'),
      constraints: const BoxConstraints(maxWidth: 640),
      child: AdminListNotice(
        icon: Icons.error_outline,
        title: 'Salon Pilot could not be granted',
        message: '${_fallback(failure.code)} (${failure.code.code})',
        error: true,
        action: failure.retryable
            ? TextButton(
                key: const Key('admin-grant-retry'),
                onPressed: onRetry,
                child: const Text('Try again'),
              )
            : TextButton(
                key: const Key('admin-grant-start-over'),
                onPressed: onEdit,
                child: const Text('Edit'),
              ),
      ),
    );
  }

  static String _fallback(AdminMutationErrorCode code) => switch (code) {
    AdminMutationErrorCode.invalidRequest =>
      'The server did not accept the request as sent.',
    AdminMutationErrorCode.userNotFound =>
      'No FaceTune account matches that user id.',
    AdminMutationErrorCode.salonPilotAlreadyGranted =>
      'This account already holds a Salon Pilot entitlement that is in force.',
    AdminMutationErrorCode.providerStateConflict =>
      'This account has a store subscription in force.',
    AdminMutationErrorCode.idempotencyConflict =>
      'This request was already submitted with different values.',
    AdminMutationErrorCode.concurrentModification =>
      'The entitlement changed while you were working.',
    _ => 'The grant could not be completed.',
  };
}
