import 'package:facetune/core/config/supabase_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabaseConfig', () {
    test('compile-time environment contract is internally consistent', () {
      const expectConfigured = bool.fromEnvironment('EXPECT_SUPABASE_CONFIG');
      final config = SupabaseConfig.fromEnvironment();

      expect(config.url.isEmpty, config.publishableKey.isEmpty);
      if (expectConfigured) {
        expect(config.isConfigured, isTrue);
        expect(config.validate, returnsNormally);
      }
    });

    test('accepts an HTTPS project URL and publishable key', () {
      const config = SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: 'sb_publishable_example',
      );

      expect(config.isConfigured, isTrue);
      expect(config.validate, returnsNormally);
    });

    test('rejects a dashboard URL', () {
      const config = SupabaseConfig(
        url: 'https://supabase.com/dashboard/project/example',
        publishableKey: 'sb_publishable_example',
      );

      expect(config.validate, throwsA(isA<SupabaseConfigurationException>()));
    });

    test('rejects server-side or legacy key formats', () {
      const config = SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: 'service-role-key',
      );

      expect(config.validate, throwsA(isA<SupabaseConfigurationException>()));
    });
  });
}
