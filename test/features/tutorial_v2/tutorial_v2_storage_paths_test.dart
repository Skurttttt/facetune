import 'package:facetune/features/tutorial_v2/domain/services/tutorial_v2_storage_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const userId = 'user-1';
  const analysisId = 'analysis-1';
  const sessionId = 'session-1';

  String guideline(int index) => TutorialV2StoragePaths.guideline(
    userId: userId,
    analysisId: analysisId,
    sessionId: sessionId,
    stepIndex: index,
  );

  String result(int index) => TutorialV2StoragePaths.result(
    userId: userId,
    analysisId: analysisId,
    sessionId: sessionId,
    stepIndex: index,
  );

  bool owned(String path, {int? stepIndex, String? asset}) =>
      TutorialV2StoragePaths.isOwnedAssetPath(
        path,
        userId: userId,
        analysisId: analysisId,
        sessionId: sessionId,
        stepIndex: stepIndex,
        asset: asset,
      );

  group('path construction', () {
    test('assets sit under the analysis prefix history deletion sweeps', () {
      expect(
        guideline(0),
        'user-1/analyses/analysis-1/tutorial-v2/session-1/step_0001_guideline.png',
      );
      expect(
        result(0),
        'user-1/analyses/analysis-1/tutorial-v2/session-1/step_0001_result.png',
      );
    });

    test('the first segment is the owner id', () {
      // storage RLS checks storage.foldername(name)[1] = auth.uid().
      expect(guideline(3).split('/').first, userId);
    });

    test('step numbers are one-based and zero-padded', () {
      expect(guideline(0), contains('step_0001_'));
      expect(guideline(9), contains('step_0010_'));
      expect(result(998), contains('step_0999_'));
    });

    test('the extension is honoured and lowercased', () {
      expect(
        TutorialV2StoragePaths.result(
          userId: userId,
          analysisId: analysisId,
          sessionId: sessionId,
          stepIndex: 0,
          extension: 'WEBP',
        ),
        endsWith('.webp'),
      );
    });

    test('a negative step index is rejected', () {
      expect(() => guideline(-1), throwsArgumentError);
    });

    test('guideline and result never collide', () {
      expect(guideline(2), isNot(result(2)));
    });

    test('the session directory is the shared prefix', () {
      final directory = TutorialV2StoragePaths.sessionDirectory(
        userId: userId,
        analysisId: analysisId,
        sessionId: sessionId,
      );
      expect(guideline(0), startsWith('$directory/'));
      expect(result(0), startsWith('$directory/'));
    });
  });

  group('ownership validation', () {
    test('accepts a path it built', () {
      expect(owned(guideline(0)), isTrue);
      expect(owned(result(4)), isTrue);
    });

    test('pins the step index when asked', () {
      expect(owned(guideline(0), stepIndex: 0), isTrue);
      expect(owned(guideline(0), stepIndex: 1), isFalse);
    });

    test('pins the asset kind when asked', () {
      expect(owned(guideline(0), asset: 'guideline'), isTrue);
      expect(owned(guideline(0), asset: 'result'), isFalse);
      expect(owned(result(0), asset: 'result'), isTrue);
    });

    test('rejects another user', () {
      expect(
        owned(
          'user-2/analyses/analysis-1/tutorial-v2/session-1/step_0001_result.png',
        ),
        isFalse,
      );
    });

    test('rejects another analysis', () {
      expect(
        owned(
          'user-1/analyses/analysis-9/tutorial-v2/session-1/step_0001_result.png',
        ),
        isFalse,
      );
    });

    test('rejects another session', () {
      expect(
        owned(
          'user-1/analyses/analysis-1/tutorial-v2/session-9/step_0001_result.png',
        ),
        isFalse,
      );
    });

    test('rejects traversal rather than accepting a prefix match', () {
      // A startsWith test would accept these.
      expect(
        owned(
          'user-1/analyses/analysis-1/tutorial-v2/session-1/../../step_0001_result.png',
        ),
        isFalse,
      );
      expect(
        owned(
          'user-1/analyses/analysis-1/tutorial-v2/session-1/nested/step_0001_result.png',
        ),
        isFalse,
      );
    });

    test('rejects an original selfie path', () {
      expect(
        owned('user-1/analyses/analysis-1/original/abcd.jpg'),
        isFalse,
      );
    });

    test('rejects a canonical preview path', () {
      expect(
        owned(
          'user-1/analyses/analysis-1/generated/rec-1/preview_0001.png',
        ),
        isFalse,
      );
    });

    test('rejects an unexpected file name', () {
      const base = 'user-1/analyses/analysis-1/tutorial-v2/session-1';
      for (final name in [
        'step_1_result.png',
        'step_0001_final.png',
        'result.png',
        'step_0001_result',
        'step_0001_result.exe',
      ]) {
        expect(owned('$base/$name'), isFalse, reason: name);
      }
    });

    test('rejects an empty path', () {
      expect(owned(''), isFalse);
    });
  });

  group('step index extraction', () {
    test('round-trips the index it encoded', () {
      for (final index in [0, 1, 9, 42]) {
        expect(TutorialV2StoragePaths.stepIndexOf(guideline(index)), index);
        expect(TutorialV2StoragePaths.stepIndexOf(result(index)), index);
      }
    });

    test('returns null for a non-asset path', () {
      expect(
        TutorialV2StoragePaths.stepIndexOf(
          'user-1/analyses/analysis-1/original/abcd.jpg',
        ),
        isNull,
      );
      expect(TutorialV2StoragePaths.stepIndexOf(''), isNull);
    });

    test('returns null for a zero step number', () {
      expect(
        TutorialV2StoragePaths.stepIndexOf(
          'user-1/analyses/analysis-1/tutorial-v2/session-1/step_0000_result.png',
        ),
        isNull,
      );
    });
  });
}
