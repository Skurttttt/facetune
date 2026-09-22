import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../auth/domain/admin_auth_failure.dart';
import '../../auth/presentation/admin_authorization_controller.dart';
import '../../auth/presentation/admin_authorization_state.dart';
import '../data/admin_salon_pilot_gateway_provider.dart';
import '../domain/admin_salon_pilot_gateway.dart';
import '../domain/admin_salon_pilot_models.dart';

sealed class AdminGrantSalonPilotState {
  const AdminGrantSalonPilotState();
}

/// The form is open; nothing has been sent.
final class AdminGrantEditing extends AdminGrantSalonPilotState {
  const AdminGrantEditing();
}

/// The admin is reviewing exactly what will be sent. The intent — and its
/// idempotency key — is frozen here; going back to edit discards it.
final class AdminGrantPreviewing extends AdminGrantSalonPilotState {
  const AdminGrantPreviewing(this.intent);

  final GrantSalonPilotIntent intent;
}

final class AdminGrantSubmitting extends AdminGrantSalonPilotState {
  const AdminGrantSubmitting(this.intent);

  final GrantSalonPilotIntent intent;
}

final class AdminGrantSucceeded extends AdminGrantSalonPilotState {
  const AdminGrantSucceeded(this.intent, this.outcome);

  final GrantSalonPilotIntent intent;
  final AdminMutationOutcome outcome;
}

/// The server refused or could not complete the grant. The same intent
/// (same key) is retained so a retry is the same business action.
final class AdminGrantFailed extends AdminGrantSalonPilotState {
  const AdminGrantFailed(this.intent, this.failure);

  final GrantSalonPilotIntent intent;
  final AdminMutationFailure failure;
}

final adminGrantSalonPilotControllerProvider = StateNotifierProvider.autoDispose
    .family<AdminGrantSalonPilotController, AdminGrantSalonPilotState, String>((
      ref,
      targetUserId,
    ) {
      return AdminGrantSalonPilotController(
        targetUserId: targetUserId,
        gateway: ref.watch(adminSalonPilotGatewayProvider),
        isAuthorized: () =>
            ref.read(adminAuthorizationControllerProvider) is AdminAuthorized,
        onServerRefusal: ref
            .read(adminAuthorizationControllerProvider.notifier)
            .handleServerRefusal,
      );
    });

/// Drives one grant: preview → confirm → result.
///
/// The controller mints the idempotency key when the admin asks for a
/// preview, so the key names exactly the values shown on screen. Confirm,
/// and any retry after a temporary failure, send that same key; the server
/// treats a duplicate as a replay of the first grant, never as a second one.
class AdminGrantSalonPilotController
    extends StateNotifier<AdminGrantSalonPilotState> {
  AdminGrantSalonPilotController({
    required this.targetUserId,
    required AdminSalonPilotGateway gateway,
    required bool Function() isAuthorized,
    required void Function(AdminAuthFailure failure) onServerRefusal,
    String Function()? mintIdempotencyKey,
  }) : _gateway = gateway,
       _isAuthorized = isAuthorized,
       _onServerRefusal = onServerRefusal,
       _mintIdempotencyKey = mintIdempotencyKey ?? _randomKey,
       super(const AdminGrantEditing());

  final String targetUserId;
  final AdminSalonPilotGateway _gateway;
  final bool Function() _isAuthorized;
  final void Function(AdminAuthFailure failure) _onServerRefusal;
  final String Function() _mintIdempotencyKey;

  static String _randomKey() => const Uuid().v4();

  void preview({
    required DateTime expiresAt,
    required int initialAllowance,
    required String reason,
  }) {
    state = AdminGrantPreviewing(
      GrantSalonPilotIntent(
        targetUserId: targetUserId,
        expiresAt: expiresAt.toUtc(),
        initialAllowance: initialAllowance,
        reason: reason.trim(),
        idempotencyKey: _mintIdempotencyKey(),
      ),
    );
  }

  void edit() => state = const AdminGrantEditing();

  Future<void> confirm() async {
    final current = state;
    final intent = switch (current) {
      AdminGrantPreviewing(:final intent) => intent,
      AdminGrantFailed(:final intent) => intent,
      _ => null,
    };
    if (intent == null) return;
    if (!_isAuthorized()) {
      state = AdminGrantFailed(
        intent,
        const AdminMutationFailure(
          AdminMutationErrorCode.temporaryBackendFailure,
        ),
      );
      return;
    }
    state = AdminGrantSubmitting(intent);
    try {
      final outcome = await _gateway.grantSalonPilot(intent);
      state = AdminGrantSucceeded(intent, outcome);
    } on AdminAuthFailure catch (failure) {
      _onServerRefusal(failure);
      state = AdminGrantFailed(
        intent,
        const AdminMutationFailure(
          AdminMutationErrorCode.temporaryBackendFailure,
        ),
      );
    } on AdminMutationFailure catch (failure) {
      state = AdminGrantFailed(intent, failure);
    } catch (_) {
      state = AdminGrantFailed(
        intent,
        const AdminMutationFailure(
          AdminMutationErrorCode.temporaryBackendFailure,
          retryable: true,
        ),
      );
    }
  }
}
