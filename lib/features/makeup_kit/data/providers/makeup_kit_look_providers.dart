import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_availability_provider.dart';
import '../../../../core/supabase/supabase_client_provider.dart';
import '../../domain/repositories/makeup_kit_look_repository.dart';
import '../data_sources/makeup_kit_look_remote_data_source.dart';
import '../data_sources/pdmk_pending_request_store.dart';
import '../repositories/supabase_makeup_kit_look_repository.dart';
import '../repositories/unavailable_makeup_kit_look_repository.dart';

/// One durable store per app process, so its serialized writes cannot race a
/// second instance over the same file. Absent on the web, which has no private
/// support directory; requests there carry no plan request id.
final pdmkPendingRequestStoreProvider = Provider<PdmkPendingRequestStore?>(
  (ref) => kIsWeb ? null : FilePdmkPendingRequestStore(),
);

final makeupKitLookRepositoryProvider = Provider<MakeupKitLookRepository>((
  ref,
) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const UnavailableMakeupKitLookRepository();
  }
  return SupabaseMakeupKitLookRepository(
    SupabaseMakeupKitLookRemoteDataSource(ref.watch(supabaseClientProvider)),
    pendingRequests: ref.watch(pdmkPendingRequestStoreProvider),
  );
});
