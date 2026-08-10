import 'package:facetune/core/config/supabase_config.dart';
import 'package:facetune/core/supabase/supabase_initialization_result.dart';
import 'package:facetune/core/supabase/supabase_initializer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports missing configuration without initializing a client', () async {
    final result = await SupabaseInitializer.initialize(
      const SupabaseConfig(url: '', publishableKey: ''),
    );

    expect(result.status, SupabaseInitializationStatus.missingConfiguration);
    expect(result.urlConfigured, isFalse);
    expect(result.publishableKeyConfigured, isFalse);
  });

  test('reports invalid configuration without exposing values', () async {
    final result = await SupabaseInitializer.initialize(
      const SupabaseConfig(
        url: 'https://supabase.com/dashboard/project/example',
        publishableKey: 'sb_publishable_example',
      ),
    );

    expect(result.status, SupabaseInitializationStatus.invalidConfiguration);
    expect(result.userMessage, isNot(contains('sb_publishable_example')));
  });
}
