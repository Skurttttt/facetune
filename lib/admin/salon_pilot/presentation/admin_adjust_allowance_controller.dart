import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../auth/domain/admin_auth_failure.dart';
import '../../auth/presentation/admin_authorization_controller.dart';
import '../../auth/presentation/admin_authorization_state.dart';
import '../data/admin_salon_pilot_gateway_provider.dart';
import '../domain/admin_salon_pilot_gateway.dart';
import '../domain/admin_salon_pilot_models.dart';

sealed class AdminAdjustAllowanceState {
  const AdminAdjustAllowanceState();
}

final class AdminAdjustEditing extends AdminAdjustAllowanceState {
  const AdminAdjustEditing();
}

/// The admin is reviewing the informational preview. The intent — its
/// idempotency key and the version it was based on — is frozen here.
final class AdminAdjustPreviewing extends AdminAdjustAllowanceState {
  const AdminAdjustPreviewing(this.intent, this.preview);

  final AdjustAllowanceIntent intent;
  final AllowanceAdjustmentPreview preview;
}

final class AdminAdjustSubmitting extends AdminAdjustAllowanceState {
  const AdminAdjustSubmitting(this.intent);

  final AdjustAllowanceIntent intent;
}

final class AdminAdjustSucceeded extends AdminAdjustAllowanceState {
  const AdminAdjustSucceeded(this.intent, this.outcome);

  final AdjustAllowanceIntent intent;
  final AdminMutationOutcome outcome;
}

final class AdminAdjustFailed extends AdminAdjustAllowanceState {
  const AdminAdjustFailed(this.intent, this.failure);

  final AdjustAllowanceIntent intent;
  final AdminMutationFailure failure;
}

/// Keyed by the entitlement being adjusted.
final adminAdjustAllowanceControllerProvider = StateNotifierProvider.autoDispose
    .family<AdminAdjustAllowanceController, AdminAdjustAllowanceState, String>((
      ref,
      entitlementId,
    ) {
      return AdminAdjustAllowanceController(
        entitlementId: entitlementId,
        gateway: ref.watch(adminSalonPilotGatewayProvider),
        isAuthorized: () =>
            ref.read(adminAuthorizationControllerProvider) is AdminAuthorized,
        onServerRefusal: ref
            .read(adminAuthorizationControllerProvider.notifier)
            .handleServerRefusal,
      );
    });

/// Drives one adjustment: preview → confirm → result, on the WA-7 pattern.
///
/// The idempotency key is minted at preview so it names exactly the amount,
/// reason, and version shown on screen. Confirm and any retry after a
/// temporary failure reuse it; the server applies the change once.
class AdminAdjustAllowanceController
    extends StateNotifier<AdminAdjustAllowanceState> {
  AdminAdjustAllowanceController({
    required this.entitlementId,
    required AdminSalonPilotGateway gateway,
    required bool Function() isAuthorized,
    required void Function(AdminAuthFailure failure) onServerRefusal,
    String Function()? mintIdempotencyKey,
  }) : _gateway = gateway,
       _isAuthorized = isAuthorized,
       _onServerRefusal = onServerRefusal,
       _mintIdempotencyKey = mintIdempotencyKey ?? _randomKey,
       super(const AdminAdjustEditing());

  final String entitlementId;
  final AdminSalonPilotGateway _gateway;
  final bool Function() _isAuthorized;
  final void Function(AdminAuthFailure failure) _onServerRefusal;
  final String Function() _mintIdempotencyKey;

  static String _randomKey() => const Uuid().v4();

  /// Freezes the intent against the server figures the admin is looking at.
  void preview({
    required int amount,
    required String reason,
    required int currentEffectiveAllowance,
    required int committedUsage,
    required int reservedUsage,
    required int? expectedVersion,
  }) {
    state = AdminAdjustPreviewing(
      AdjustAllowanceIntent(
        entitlementId: entitlementId,
        amount: amount,
        reason: reason.trim(),
        idempotencyKey: _mintIdempotencyKey(),
        expectedVersion: expectedVersion,
      ),
      AllowanceAdjustmentPreview(
        currentEffectiveAllowance: currentEffectiveAllowance,
        amount: amount,
        committedUsage: committedUsage,
        reservedUsage: reservedUsage,
      ),
    );
  }

  void edit() => state = const AdminAdjustEditing();

  Future<void> confirm() async {
    final current = state;
    final intent = switch (current) {
      AdminAdjustPreviewing(:final intent) => intent,
      AdminAdjustFailed(:final intent) => intent,
      _ => null,
    };
    if (intent == null) return;
    if (!_isAuthorized()) {
      state = AdminAdjustFailed(
        intent,
        const AdminMutationFailure(
          AdminMutationErrorCode.temporaryBackendFailure,
        ),
      );
      return;
    }
    state = AdminAdjustSubmitting(intent);
    try {
      final outcome = await _gateway.adjustAllowance(intent);
      state = AdminAdjustSucceeded(intent, outcome);
    } on AdminAuthFailure catch (failure) {
      _onServerRefusal(failure);
      state = AdminAdjustFailed(
        intent,
        const AdminMutationFailure(
          AdminMutationErrorCode.temporaryBackendFailure,
        ),
      );
    } on AdminMutationFailure catch (failure) {
      state = AdminAdjustFailed(intent, failure);
    } catch (_) {
      state = AdminAdjustFailed(
        intent,
        const AdminMutationFailure(
          AdminMutationErrorCode.temporaryBackendFailure,
          retryable: true,
        ),
      );
    }
  }
}
