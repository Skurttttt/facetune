import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_look_providers.dart';
import 'package:facetune/features/makeup_kit/data/repositories/pdmk_pending_preview_resumer.dart';
import 'package:facetune/features/makeup_kit/presentation/widgets/pdmk_preview_resume_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_auth_repository.dart';

/// PDMK-6: an interrupted plan-driven preview is continued when the app starts
/// and whenever it returns to the foreground — only for a signed-in user.
class _CountingResumer implements PdmkPendingPreviewResumer {
  int resumes = 0;

  @override
  Future<void> resume() async => resumes++;
}

Future<_CountingResumer> _pump(
  WidgetTester tester, {
  bool signedIn = true,
}) async {
  final auth = FakeAuthRepository(
    user: signedIn
        ? const AuthUser(id: 'account-uuid', isAnonymous: false)
        : null,
  );
  addTearDown(auth.dispose);
  final resumer = _CountingResumer();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(auth),
        pdmkPendingPreviewResumerProvider.overrideWithValue(resumer),
      ],
      child: const MaterialApp(
        home: PdmkPreviewResumeListener(child: Text('home')),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return resumer;
}

Future<void> _backgroundThenResume(WidgetTester tester) async {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a signed-in launch continues a pending preview', (tester) async {
    final resumer = await _pump(tester);
    expect(resumer.resumes, 1);
  });

  testWidgets('returning to the foreground continues it again', (tester) async {
    final resumer = await _pump(tester);
    await _backgroundThenResume(tester);
    expect(resumer.resumes, 2);
  });

  testWidgets('a signed-out app continues nothing', (tester) async {
    final resumer = await _pump(tester, signedIn: false);
    await _backgroundThenResume(tester);
    expect(resumer.resumes, 0);
  });
}
