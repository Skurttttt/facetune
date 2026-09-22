import 'admin_salon_pilot_models.dart';

abstract interface class AdminSalonPilotGateway {
  /// Submits the grant. Throws [AdminMutationFailure] for a refused or
  /// failed mutation and `AdminAuthFailure` for a session refusal.
  Future<AdminMutationOutcome> grantSalonPilot(GrantSalonPilotIntent intent);

  /// Submits an allowance adjustment (WA-8). Same failure contract.
  Future<AdminMutationOutcome> adjustAllowance(AdjustAllowanceIntent intent);

  /// Submits a lifecycle change (WA-9). Same failure contract.
  Future<AdminMutationOutcome> applyLifecycle(LifecycleIntent intent);
}
