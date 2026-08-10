// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:facetune/app/app.dart';
import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';

import 'helpers/fake_auth_repository.dart';

void main() {
  testWidgets('Start Scan opens the static scan experience', (tester) async {
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

    await tester.tap(find.text('Start Scan'));
    await tester.pumpAndSettle();

    expect(find.text('New scan'), findsOneWidget);
    expect(find.text('Center your face in the frame'), findsOneWidget);
    await repository.dispose();
  });
}
