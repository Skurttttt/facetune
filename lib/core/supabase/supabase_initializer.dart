import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'supabase_initialization_result.dart';

abstract final class SupabaseInitializer {
  static Future<SupabaseInitializationResult> initialize(
    SupabaseConfig config,
  ) async {
    if (!config.isConfigured) {
      final result = SupabaseInitializationResult.missing(
        urlConfigured: config.url.isNotEmpty,
        publishableKeyConfigured: config.publishableKey.isNotEmpty,
      );
      _log(result);
      return result;
    }

    try {
      config.validate();
    } on SupabaseConfigurationException {
      const result = SupabaseInitializationResult.invalid();
      _log(result);
      return result;
    }

    try {
      await Supabase.initialize(
        url: config.url,
        publishableKey: config.publishableKey,
      );
      const result = SupabaseInitializationResult.ready();
      _log(result);
      return result;
    } on Object catch (error) {
      const result = SupabaseInitializationResult.failed();
      _log(result, errorType: error.runtimeType.toString());
      return result;
    }
  }

  static void _log(SupabaseInitializationResult result, {String? errorType}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      'Supabase URL configured: ${result.urlConfigured ? 'YES' : 'NO'}',
    );
    debugPrint(
      'Supabase publishable key configured: '
      '${result.publishableKeyConfigured ? 'YES' : 'NO'}',
    );
    debugPrint('Supabase initialization: ${result.status.name.toUpperCase()}');
    if (errorType != null) {
      debugPrint('Supabase initialization error type: $errorType');
    }
  }
}
