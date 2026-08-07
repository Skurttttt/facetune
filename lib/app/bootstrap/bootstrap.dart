import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../core/supabase/supabase_initializer.dart';
import '../app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseInitializer.initialize(SupabaseConfig.fromEnvironment());
  runApp(const ProviderScope(child: FaceTuneApp()));
}
