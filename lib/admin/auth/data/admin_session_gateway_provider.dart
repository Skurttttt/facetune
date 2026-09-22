import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_availability_provider.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/admin_session_gateway.dart';
import 'supabase_admin_session_gateway.dart';
import 'unavailable_admin_session_gateway.dart';

final adminSessionGatewayProvider = Provider<AdminSessionGateway>((ref) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const UnavailableAdminSessionGateway();
  }
  return SupabaseAdminSessionGateway(ref.watch(supabaseClientProvider));
});
