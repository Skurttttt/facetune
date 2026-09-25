import '../../../shared/admin_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/subscription/domain/entities/billing_provider.dart';
import '../../../../features/subscription/domain/entities/subscription_plan_code.dart';
import '../../../shared/admin_dialogs.dart';
import '../../../shared/admin_form_widgets.dart';
import '../../../theme/admin_tokens.dart';
import '../../../app/admin_routes.dart';
import '../../../shared/admin_labels.dart';
import '../../../shared/admin_list_widgets.dart';
import '../../../users/domain/admin_user_models.dart';
import '../../../users/presentation/admin_users_controller.dart';
import '../../domain/admin_salon_pilot_models.dart';
import '../admin_lifecycle_controller.dart';

/// One Salon Pilot lifecycle action for one account: extend expiration,
/// suspend, reactivate, or revoke. Form → preview → confirm → the server's
/// authoritative state. Revocation carries the high-friction confirmation
/// the SOT requires (§31): consequence text, an explicit acknowledgement,
/// a reason, and an unambiguous button label.
class AdminLifecyclePage extends ConsumerStatefulWidget {
  const AdminLifecyclePage({
    super.key,
    required this.userId,
    required this.action,
  });

  final String userId;
  final SalonPilotLifecycleAction action;

  @override
  ConsumerState<AdminLifecyclePage> createState() => _AdminLifecyclePageState();
}

class _AdminLifecyclePageState extends ConsumerState<AdminLifecyclePage> {
  final _date = TextEditingController();
  final _reason = TextEditingController();
  String? _dateError;
  String? _reasonError;
  bool _acknowledged = false;
  String? _acknowledgeError;

  @override
  void dispose() {
    _date.dispose();
    _reason.dispose();
    super.dispose();
  }

  bool get _isExtension =>
      widget.action == SalonPilotLifecycleAction.extendExpiration;

  /// The typed date as the end of that UTC day; null when not a date.
  static DateTime? parseDate(String text) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text.trim());
    if (match == null) return null;
    final day = DateTime.tryParse('${match[0]}T00:00:00Z');
    if (day == null ||
        day.year != int.parse(match[1]!) ||
        day.month != int.parse(match[2]!) ||
        day.day != int.parse(match[3]!)) {
      return null;
    }
    return DateTime.utc(day.year, day.month, day.day, 23, 59, 59);
  }

  AdminLifecycleKey _key(AdminEntitlementDetail entitlement) =>
      (entitlementId: entitlement.entitlementId, action: widget.action);

  Future<void> _pickDate(AdminEntitlementDetail entitlement) async {
    final now = DateTime.now().toUtc();
    final current = entitlement.expiresAt ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate:
          parseDate(_date.text) ?? current.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
      helpText: 'New expiration (UTC)',
    );
    if (picked == null) return;
    setState(() {
      _date.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      _dateError = null;
    });
  }

  Future<void> _preview(
    AdminEntitlementDetail entitlement,
    String account,
  ) async {
    final reason = _reason.text.trim();
    DateTime? newExpiresAt;
    String? dateError;
    if (_isExtension) {
      newExpiresAt = parseDate(_date.text);
      final current = entitlement.expiresAt;
      dateError = newExpiresAt == null
          ? 'Enter the new expiration as YYYY-MM-DD.'
          : !newExpiresAt.isAfter(DateTime.now().toUtc())
          ? 'The new expiration must be in the future.'
          : current != null && !newExpiresAt.isAfter(current)
          ? 'The new expiration must be later than the current one.'
          : null;
    }
    final reasonError = reason.isEmpty
        ? 'A reason is required.'
        : reason.length > adminReasonMaxLength
        ? 'Keep the reason under $adminReasonMaxLength characters.'
        : null;
    final acknowledgeError = widget.action.highRisk && !_acknowledged
        ? 'Confirm that you understand this cannot be undone.'
        : null;
    setState(() {
      _dateError = dateError;
      _reasonError = reasonError;
      _acknowledgeError = acknowledgeError;
    });
    if (dateError != null || reasonError != null || acknowledgeError != null) {
      return;
    }
    final provider = adminLifecycleControllerProvider(_key(entitlement));
    final controller = ref.read(provider.notifier);
    controller.preview(
      reason: reason,
      expectedVersion: entitlement.version,
      newExpiresAt: newExpiresAt,
    );
    final state = ref.read(provider);
    if (state is! AdminLifecyclePreviewing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _Preview(
        account: account,
        intent: state.intent,
        entitlement: entitlement,
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      await controller.confirm();
    } else {
      controller.edit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(adminUserDetailControllerProvider(widget.userId));
    return Column(
      key: Key('admin-lifecycle-${widget.action.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          key: const Key('admin-lifecycle-back'),
          onPressed: () => context.go(AdminRoutes.userDetail(widget.userId)),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back to user'),
        ),
        const SizedBox(height: AdminSpacing.xs),
        AdminPageHeader(
          title: '${widget.action.label} — Salon Pilot',
          subtitle: widget.action.consequence,
        ),
        const SizedBox(height: AdminSpacing.lg),
        switch (detail) {
          AdminUserDetailLoading() => const AdminListLoadingRow(
            key: Key('admin-lifecycle-loading'),
            label: 'Loading entitlement',
          ),
          AdminUserDetailNotFound() => const AdminListNotice(
            key: Key('admin-lifecycle-not-found'),
            icon: Icons.info_outline,
            message: 'User not found.',
          ),
          AdminUserDetailUnavailable() => const AdminListNotice(
            key: Key('admin-lifecycle-unavailable'),
            icon: Icons.error_outline,
            message: 'The entitlement could not be loaded.',
          ),
          AdminUserDetailReady(:final detail) => _body(detail),
        },
      ],
    );
  }

  Widget _body(AdminUserDetail detail) {
    final entitlement = detail.entitlement;
    if (entitlement == null ||
        entitlement.planCode != SubscriptionPlanCode.salonPilot ||
        entitlement.billingProvider != BillingProvider.adminGranted) {
      return const AdminListNotice(
        key: Key('admin-lifecycle-not-editable'),
        icon: Icons.info_outline,
        message:
            'This account has no admin-granted Salon Pilot entitlement. '
            'Store-backed subscriptions follow the provider lifecycle and '
            'cannot be changed here.',
      );
    }
    final state = ref.watch(
      adminLifecycleControllerProvider(_key(entitlement)),
    );
    final controller = ref.read(
      adminLifecycleControllerProvider(_key(entitlement)).notifier,
    );
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          key: const Key('admin-lifecycle-current'),
          constraints: const BoxConstraints(maxWidth: 640),
          child: _Panel(
            title: 'Current (server)',
            theme: theme,
            rows: [
              ('Account', detail.email ?? detail.userId),
              ('Entitlement ID', entitlement.entitlementId),
              (
                'Stored status',
                entitlementStatusLabel(entitlement.storedStatus),
              ),
              (
                'Effective status',
                entitlementStatusLabel(entitlement.effectiveStatus),
              ),
              (
                'Expires',
                entitlement.expiresAt == null
                    ? 'Not applicable'
                    : formatUtcDateTime(entitlement.expiresAt!),
              ),
              ('Effective allowance', '${entitlement.effectiveAllowance}'),
              ('Committed', '${entitlement.committedUsage}'),
              ('Reserved', '${entitlement.reservedUsage}'),
              ('Version', '${entitlement.version}'),
            ],
          ),
        ),
        const SizedBox(height: AdminSpacing.lg),
        switch (state) {
          AdminLifecycleEditing() => _form(
            entitlement,
            detail.email ?? detail.userId,
          ),
          AdminLifecyclePreviewing() => const SizedBox.shrink(),
          AdminLifecycleSubmitting() => AdminListLoadingRow(
            key: const Key('admin-lifecycle-submitting'),
            label: 'Applying: ${widget.action.label}',
          ),
          AdminLifecycleSucceeded(:final intent, :final outcome) => _Result(
            intent: intent,
            outcome: outcome,
            userId: widget.userId,
          ),
          AdminLifecycleFailed(:final failure) => _Failure(
            failure: failure,
            onRetry: controller.confirm,
            onEdit: () {
              controller.edit();
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

  Widget _form(AdminEntitlementDetail entitlement, String account) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      key: const Key('admin-lifecycle-form'),
      constraints: const BoxConstraints(maxWidth: 640),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isExtension) ...[
            AdminLabeledField(
              label: 'New expiration date (UTC)',
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('admin-lifecycle-date'),
                      controller: _date,
                      keyboardType: TextInputType.datetime,
                      decoration: InputDecoration(
                        helperText:
                            'YYYY-MM-DD, later than the current expiration. The '
                            'term ends at the end of that day.',
                        errorText: _dateError,
                      ),
                    ),
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  OutlinedButton.icon(
                    key: const Key('admin-lifecycle-pick-date'),
                    onPressed: () => _pickDate(entitlement),
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: const Text('Pick date'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AdminSpacing.md),
          ],
          AdminLabeledField(
            label: 'Reason',
            child: TextField(
              key: const Key('admin-lifecycle-reason'),
              controller: _reason,
              maxLines: 3,
              maxLength: adminReasonMaxLength,
              decoration: InputDecoration(
                helperText: 'Required. Operational and privacy-conscious.',
                errorText: _reasonError,
              ),
            ),
          ),
          if (widget.action.highRisk) ...[
            const SizedBox(height: AdminSpacing.sm),
            CheckboxListTile(
              key: const Key('admin-lifecycle-acknowledge'),
              value: _acknowledged,
              onChanged: (value) => setState(() {
                _acknowledged = value ?? false;
                if (_acknowledged) _acknowledgeError = null;
              }),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'I understand this revokes access permanently and cannot be undone.',
              ),
              subtitle: _acknowledgeError == null
                  ? null
                  : Text(
                      _acknowledgeError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
            ),
          ],
          const SizedBox(height: AdminSpacing.lg),
          FilledButton.icon(
            key: const Key('admin-lifecycle-preview'),
            onPressed: () => _preview(entitlement, account),
            icon: const Icon(Icons.preview_outlined, size: 18),
            label: const Text('Review'),
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.account,
    required this.intent,
    required this.entitlement,
    required this.onCancel,
    required this.onConfirm,
  });

  final String account;
  final LifecycleIntent intent;
  final AdminEntitlementDetail entitlement;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = intent.action;
    final rows = <(String, String)>[
      ('Account', account),
      ('Entitlement ID', entitlement.entitlementId),
      ('Action', action.label),
      ('Current status', entitlementStatusLabel(entitlement.storedStatus)),
      if (action == SalonPilotLifecycleAction.extendExpiration) ...[
        (
          'Current expiration',
          entitlement.expiresAt == null
              ? 'Not applicable'
              : formatUtcDateTime(entitlement.expiresAt!),
        ),
        ('New expiration', formatUtcDateTime(intent.newExpiresAt!)),
      ] else
        (
          'New status',
          switch (action) {
            SalonPilotLifecycleAction.suspend => 'Suspended',
            SalonPilotLifecycleAction.reactivate => 'Active',
            SalonPilotLifecycleAction.revoke => 'Revoked',
            SalonPilotLifecycleAction.extendExpiration => '',
          },
        ),
      ('Reason', intent.reason),
      ('Based on version', '${intent.expectedVersion ?? 'not checked'}'),
    ];
    return AdminConfirmationDialog(
      key: const Key('admin-lifecycle-preview-panel'),
      title: action.highRisk ? 'Revoke Salon Pilot?' : 'Review before applying',
      description: action.highRisk
          ? 'Confirm this permanent entitlement change for the target below.'
          : 'Confirm the target and frozen lifecycle change below.',
      confirmLabel: action.confirmLabel,
      confirmButtonKey: const Key('admin-lifecycle-confirm'),
      cancelButtonKey: const Key('admin-lifecycle-edit'),
      confirmIcon: action.highRisk ? Icons.block : Icons.check,
      destructive: action.highRisk,
      onConfirm: onConfirm,
      onCancel: onCancel,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminDialogDetailRows(rows: rows),
          const SizedBox(height: AdminSpacing.sm),
          Text(
            action.consequence,
            key: const Key('admin-lifecycle-consequence'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: action.highRisk ? theme.colorScheme.error : null,
            ),
          ),
          const SizedBox(height: AdminSpacing.xs),
          Text(
            'The server validates the transition and provider boundary, '
            'records one audit event under your admin identity, and replays '
            'a duplicate submission instead of applying it twice.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.intent,
    required this.outcome,
    required this.userId,
  });

  final LifecycleIntent intent;
  final AdminMutationOutcome outcome;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      key: const Key('admin-lifecycle-succeeded'),
      constraints: const BoxConstraints(maxWidth: 640),
      child: _Panel(
        title: outcome.replayed
            ? '${intent.action.label}: already applied by this request'
            : '${intent.action.label}: applied',
        theme: theme,
        highlighted: true,
        rows: [
          ('Status', entitlementStatusLabel(outcome.status)),
          (
            'Expires',
            outcome.expiresAt == null
                ? 'Not applicable'
                : formatUtcDateTime(outcome.expiresAt!),
          ),
          ('Effective allowance', '${outcome.effectiveAllowance}'),
          ('Committed', '${outcome.committedUsage}'),
          ('Reserved', '${outcome.reservedUsage}'),
          ('Available from this entitlement', '${outcome.availableAiLooks}'),
          ('Updated', formatUtcDateTime(outcome.updatedAt)),
        ],
        footer: FilledButton(
          key: const Key('admin-lifecycle-done'),
          onPressed: () => context.go(AdminRoutes.userDetail(userId)),
          child: const Text('Back to user'),
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
  Widget build(BuildContext context) => ConstrainedBox(
    key: const Key('admin-lifecycle-failed'),
    constraints: const BoxConstraints(maxWidth: 640),
    child: AdminListNotice(
      icon: Icons.error_outline,
      message:
          '${failure.message ?? _fallback(failure.code)} (${failure.code.code})',
      action: failure.retryable
          ? TextButton(
              key: const Key('admin-lifecycle-retry'),
              onPressed: onRetry,
              child: const Text('Try again'),
            )
          : TextButton(
              key: const Key('admin-lifecycle-start-over'),
              onPressed: onEdit,
              child: const Text('Reload and edit'),
            ),
    ),
  );

  static String _fallback(AdminMutationErrorCode code) => switch (code) {
    AdminMutationErrorCode.invalidEntitlementTransition =>
      'This action is not allowed from the entitlement\'s current status.',
    AdminMutationErrorCode.providerStateConflict =>
      'Store-backed subscriptions follow the provider lifecycle and cannot be changed here.',
    AdminMutationErrorCode.entitlementExpired =>
      'This entitlement has ended. Extend its expiration first if it should continue.',
    AdminMutationErrorCode.entitlementRevoked =>
      'This entitlement was revoked; revocation is terminal.',
    AdminMutationErrorCode.concurrentModification =>
      'The entitlement changed while you were working.',
    AdminMutationErrorCode.idempotencyConflict =>
      'This request was already submitted with different values.',
    AdminMutationErrorCode.entitlementNotFound => 'No entitlement matches.',
    _ => 'The action could not be completed.',
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
      borderRadius: BorderRadius.circular(AdminRadii.card),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AdminSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: AdminSpacing.sm),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AdminSpacing.xxs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 220,
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
            const SizedBox(height: AdminSpacing.sm),
            footer!,
          ],
        ],
      ),
    ),
  );
}
