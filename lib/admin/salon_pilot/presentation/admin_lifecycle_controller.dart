import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../auth/domain/admin_auth_failure.dart';
import '../../auth/presentation/admin_authorization_controller.dart';
import '../../auth/presentation/admin_authorization_state.dart';
import '../data/admin_salon_pilot_gateway_provider.dart';
import '../domain/admin_salon_pilot_gateway.dart';
import '../domain/admin_salon_pilot_models.dart';

sealed class AdminLifecycleState {
  const AdminLifecycleState();
}

final class AdminLifecycleEditing extends AdminLifecycleState {
  const AdminLifecycleEditing();
}

/// The admin is reviewing exactly what will be sent; the intent — its key,
/// version, and (for an extension) date — is frozen here.
final class AdminLifecyclePreviewing extends AdminLifecycleState {
  const AdminLifecyclePreviewing(this.intent);

  final LifecycleIntent intent;
}

final class AdminLifecycleSubmitting extends AdminLifecycleState {
  const AdminLifecycleSubmitting(this.intent);

  final LifecycleIntent intent;
}

final class AdminLifecycleSucceeded extends AdminLifecycleState {
  const AdminLifecycleSucceeded(this.intent, this.outcome);

  final LifecycleIntent intent;
  final AdminMutationOutcome outcome;
}

final class AdminLifecycleFailed extends AdminLifecycleState {
  const AdminLifecycleFailed(this.intent, this.failure);

  final LifecycleIntent intent;
  final AdminMutationFailure failure;
}

/// Keyed by (entitlement, action) so each workflow has its own state.
typedef AdminLifecycleKey = ({
  String entitlementId,
  SalonPilotLifecycleAction action,
});

final adminLifecycleControllerProvider = StateNotifierProvider.autoDispose
    .family<AdminLifecycleController, AdminLifecycleState, AdminLifecycleKey>((
      ref,
      key,
    ) {
      return AdminLifecycleController(
        entitlementId: key.entitlementId,
        action: key.action,
        gateway: ref.watch(adminSalonPilotGatewayProvider),
        isAuthorized: () =>
            ref.read(adminAuthorizationControllerProvider) is AdminAuthorized,
        onServerRefusal: ref
            .read(adminAuthorizationControllerProvider.notifier)
            .handleServerRefusal,
      );
    });

/// Drives one lifecycle action: preview → confirm → result, on the WA-7 /
/// WA-8 pattern. The idempotency key is minted at preview and reused on
/// retry; the server replays rather than re-applies.
class AdminLifecycleController extends StateNotifier<AdminLifecycleState> {
  AdminLifecycleController({
    required this.entitlementId,
    required this.action,
    required AdminSalonPilotGateway gateway,
    required bool Function() isAuthorized,
    required void Function(AdminAuthFailure failure) onServerRefusal,
    String Function()? mintIdempotencyKey,
  }) : _gateway = gateway,
       _isAuthorized = isAuthorized,
       _onServerRefusal = onServerRefusal,
       _mintIdempotencyKey = mintIdempotencyKey ?? _randomKey,
       super(const AdminLifecycleEditing());

  final String entitlementId;
  final SalonPilotLifecycleAction action;
  final AdminSalonPilotGateway _gateway;
  final bool Function() _isAuthorized;
  final void Function(AdminAuthFailure failure) _onServerRefusal;
  final String Function() _mintIdempotencyKey;

  static String _randomKey() => const Uuid().v4();

  void preview({
    required String reason,
    required int? expectedVersion,
    DateTime? newExpiresAt,
  }) {
    state = AdminLifecyclePreviewing(
      LifecycleIntent(
        action: action,
        entitlementId: entitlementId,
        reason: reason.trim(),
        idempotencyKey: _mintIdempotencyKey(),
        expectedVersion: expectedVersion,
        newExpiresAt: action == SalonPilotLifecycleAction.extendExpiration
            ? newExpiresAt?.toUtc()
            : null,
      ),
    );
  }

  void edit() => state = const AdminLifecycleEditing();

  Future<void> confirm() async {
    final current = state;
    final intent = switch (current) {
      AdminLifecyclePreviewing(:final intent) => intent,
      AdminLifecycleFailed(:final intent) => intent,
      _ => null,
    };
    if (intent == null) return;
    if (!_isAuthorized()) {
      state = AdminLifecycleFailed(
        intent,
        const AdminMutationFailure(
          AdminMutationErrorCode.temporaryBackendFailure,
        ),
      );
      return;
    }
    state = AdminLifecycleSubmitting(intent);
    try {
      final outcome = await _gateway.applyLifecycle(intent);
      state = AdminLifecycleSucceeded(intent, outcome);
    } on AdminAuthFailure catch (failure) {
      _onServerRefusal(failure);
      state = AdminLifecycleFailed(
        intent,
        const AdminMutationFailure(
          AdminMutationErrorCode.temporaryBackendFailure,
        ),
      );
    } on AdminMutationFailure catch (failure) {
      state = AdminLifecycleFailed(intent, failure);
    } catch (_) {
      state = AdminLifecycleFailed(
        intent,
        const AdminMutationFailure(
          AdminMutationErrorCode.temporaryBackendFailure,
          retryable: true,
        ),
      );
    }
  }
}
