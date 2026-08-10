import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../core/supabase/supabase_initializer.dart';
import '../../core/supabase/supabase_availability_provider.dart';
import '../app.dart';

Future<void> bootstrap() async {
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
      child: const FaceTuneApp(),
    ),
  );
}
