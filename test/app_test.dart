import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:facetune/app/app.dart';
import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';

import 'helpers/fake_auth_repository.dart';

void main() {
  testWidgets('FaceTune app bootstraps with the premium home', (tester) async {
    final repository = FakeAuthRepository(
      user: const AuthUser(id: 'test-user', isAnonymous: false),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseAvailableProvider.overrideWithValue(true),
          authRepositoryProvider.overrideWithValue(repository),
        ],
        child: const FaceTuneApp(),
      ),
    );

    expect(find.text('Good morning, Mia'), findsOneWidget);
    expect(find.text('Start Scan'), findsOneWidget);
    expect(find.text('Recent looks'), findsOneWidget);
    await repository.dispose();
  });
}
