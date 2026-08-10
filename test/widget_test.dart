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
import 'package:facetune/features/analysis/data/providers/analysis_providers.dart';
import 'package:facetune/features/analysis/domain/entities/face_analysis.dart';
import 'package:facetune/features/analysis/domain/errors/analysis_failure.dart';
import 'package:facetune/features/analysis/domain/repositories/face_analysis_repository.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/scan/domain/entities/local_image_validation.dart';
import 'package:facetune/features/scan/domain/entities/prepared_selfie.dart';

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
          faceAnalysisRepositoryProvider.overrideWithValue(
            const _UnavailableAnalysisRepository(),
          ),
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

class _UnavailableAnalysisRepository implements FaceAnalysisRepository {
  const _UnavailableAnalysisRepository();

  @override
  Future<FaceAnalysis> analyze({
    required PreparedSelfie selfie,
    required LocalImageValidation localValidation,
    required void Function(AnalysisProgress progress) onProgress,
  }) {
    return Future.error(
      const AnalysisFailure(
        AnalysisFailureType.server,
        'Not used by this static navigation test.',
      ),
    );
  }
}
