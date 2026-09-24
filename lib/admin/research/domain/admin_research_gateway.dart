import '../../shared/admin_keyset_list_controller.dart';
import 'admin_research_models.dart';

/// Read-only access to the Salon Pilot research figures (WA-13).
///
/// Both calls are decided server-side against the admin roster and return
/// aggregates or per-entitlement counters only — never a selfie, image,
/// prompt, kit item, token, or purchase reference. Throws `AdminAuthFailure`
/// for a refusal and `AdminReadFailure` for anything the client cannot use.
abstract interface class AdminResearchGateway {
  Future<AdminSalonPilotResearch> fetchResearch();

  Future<AdminListPage<AdminPilotMetricsRow>> listPilots({String? cursor});
}
