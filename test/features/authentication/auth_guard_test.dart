import 'package:facetune/app/app.dart';
import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/settings/data/providers/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_account_repositories.dart';

void main() {
  testWidgets('unauthenticated users are redirected to the auth entry', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseAvailableProvider.overrideWithValue(true),
          authRepositoryProvider.overrideWithValue(repository),
          settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository(),
          ),
        ],
        child: const FaceTuneApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meet the look\nmade for you.'), findsOneWidget);
    expect(find.text('Sign in with email'), findsOneWidget);
    await repository.dispose();
  });
}
