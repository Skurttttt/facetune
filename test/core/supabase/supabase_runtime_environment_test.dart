import 'package:facetune/core/config/supabase_config.dart';
import 'package:facetune/core/supabase/supabase_initialization_result.dart';
import 'package:facetune/core/supabase/supabase_initializer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('configured runtime initializes Supabase before app startup', () async {
    const expectConfigured = bool.fromEnvironment('EXPECT_SUPABASE_CONFIG');
    if (!expectConfigured) {
      return;
    }

    TestWidgetsFlutterBinding.ensureInitialized();
    const sharedPreferencesChannel = MethodChannel(
      'plugins.flutter.io/shared_preferences',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sharedPreferencesChannel, (call) async {
          if (call.method == 'getAll') {
            return <String, Object>{};
          }
          return true;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(sharedPreferencesChannel, null);
    });

    final result = await SupabaseInitializer.initialize(
      SupabaseConfig.fromEnvironment(),
    );

    expect(result.status, SupabaseInitializationStatus.ready);
  });
}
