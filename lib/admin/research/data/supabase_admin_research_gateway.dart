import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/admin_keyset_list_controller.dart';
import '../../shared/admin_rpc.dart';
import '../domain/admin_research_gateway.dart';
import '../domain/admin_research_models.dart';

/// Calls the WA-13 research RPCs with the admin's own session.
///
/// `admin_salon_pilot_research_metrics()` takes no arguments and aggregates
/// in the database; `admin_list_salon_pilot_metrics(p_cursor)` pages the
/// per-entitlement rows 25 at a time. Neither has a filter: the population is
/// always "every Salon Pilot grant", so the only client input is the cursor.
class SupabaseAdminResearchGateway implements AdminResearchGateway {
  const SupabaseAdminResearchGateway(this._client);

  static const researchRpc = 'admin_salon_pilot_research_metrics';
  static const listRpc = 'admin_list_salon_pilot_metrics';

  final SupabaseClient _client;

  @override
  Future<AdminSalonPilotResearch> fetchResearch() async {
    final payload = await callAdminReadRpc(_client, researchRpc, const {});
    return AdminSalonPilotResearch.decode(payload);
  }

  @override
  Future<AdminListPage<AdminPilotMetricsRow>> listPilots({
    String? cursor,
  }) async {
    final payload = await callAdminReadRpc(_client, listRpc, {
      'p_cursor': cursor,
    });
    return AdminPilotMetricsRow.decodePage(payload);
  }
}
