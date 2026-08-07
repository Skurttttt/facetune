import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

abstract final class SupabaseInitializer {
  static Future<bool> initialize(SupabaseConfig config) async {
    if (!config.isConfigured) {
      return false;
    }

    config.validate();
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.publishableKey,
    );
    return true;
  }
}
