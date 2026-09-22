import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../core/supabase/supabase_availability_provider.dart';
import '../../core/supabase/supabase_initializer.dart';
import 'admin_app.dart';

/// Starts the Web Admin.
///
/// Identical Supabase initialization to the consumer app: the same
/// `--dart-define-from-file` configuration, the same publishable key, the same
/// validation that refuses anything but a publishable key. No other secret is
/// read here or anywhere under `lib/admin/`.
Future<void> bootstrapAdmin() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supabaseInitialization = await SupabaseInitializer.initialize(
    SupabaseConfig.fromEnvironment(),
  );
  runApp(
    ProviderScope(
      overrides: [
        supabaseInitializationProvider.overrideWithValue(
          supabaseInitialization,
        ),
      ],
      child: const FaceTuneAdminApp(),
    ),
  );
}
