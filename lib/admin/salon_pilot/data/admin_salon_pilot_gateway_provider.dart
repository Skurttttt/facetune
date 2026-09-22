import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_availability_provider.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/admin_salon_pilot_gateway.dart';
import '../domain/admin_salon_pilot_models.dart';
import 'supabase_admin_salon_pilot_gateway.dart';

final adminSalonPilotGatewayProvider = Provider<AdminSalonPilotGateway>((ref) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const _UnavailableAdminSalonPilotGateway();
  }
  return SupabaseAdminSalonPilotGateway(ref.watch(supabaseClientProvider));
});

class _UnavailableAdminSalonPilotGateway implements AdminSalonPilotGateway {
  const _UnavailableAdminSalonPilotGateway();

  @override
  Future<AdminMutationOutcome> grantSalonPilot(
    GrantSalonPilotIntent intent,
  ) async {
    throw const AdminMutationFailure(
      AdminMutationErrorCode.temporaryBackendFailure,
    );
  }

  @override
  Future<AdminMutationOutcome> adjustAllowance(
    AdjustAllowanceIntent intent,
  ) async {
    throw const AdminMutationFailure(
      AdminMutationErrorCode.temporaryBackendFailure,
    );
  }

  @override
  Future<AdminMutationOutcome> applyLifecycle(LifecycleIntent intent) async {
    throw const AdminMutationFailure(
      AdminMutationErrorCode.temporaryBackendFailure,
    );
  }
}
