import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_initialization_result.dart';

final supabaseInitializationProvider = Provider<SupabaseInitializationResult>(
  (ref) => const SupabaseInitializationResult.missing(
    urlConfigured: false,
    publishableKeyConfigured: false,
  ),
);

final supabaseAvailableProvider = Provider<bool>(
  (ref) => ref.watch(supabaseInitializationProvider).isReady,
);
