import 'package:facetune/features/tutorial_v3/domain/services/tutorial_v3_storage_paths.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = 'user-1';
const _analysis = 'analysis-1';
const _session = 'session-1';

String _guideline({int stepIndex = 1, String extension = 'png'}) =>
    TutorialV3StoragePaths.guideline(
      userId: _user,
      analysisId: _analysis,
      sessionId: _session,
      stepIndex: stepIndex,
      extension: extension,
    );

void main() {
  test('builds an owner-scoped, history-sweepable path', () {
    expect(
      _guideline(stepIndex: 4),
      'user-1/analyses/analysis-1/tutorial-v3/session-1/step_0004_guideline.png',
    );
  });

  test('the first segment is the owner, as storage RLS requires', () {
    expect(_guideline().split('/').first, _user);
  });

  test('the path sits under the prefix delete-history-item sweeps', () {
    expect(_guideline(), startsWith('$_user/analyses/$_analysis/'));
  });

  test('the path avoids every protected folder', () {
    final path = _guideline();
    expect(path.contains('/original/'), isFalse);
    expect(path.contains('/generated/'), isFalse);
    expect(path.contains('/kit-generated/'), isFalse);
  });

  test('step numbers are one-based and zero padded for natural sorting', () {
    expect(_guideline(stepIndex: 1), contains('step_0001_'));
    expect(_guideline(stepIndex: 12), contains('step_0012_'));

    final sorted = [
      _guideline(stepIndex: 10),
      _guideline(stepIndex: 2),
      _guideline(stepIndex: 1),
    ]..sort();
    expect(sorted, [
      _guideline(stepIndex: 1),
      _guideline(stepIndex: 2),
      _guideline(stepIndex: 10),
    ]);
  });

  test('a zero or negative step index is rejected', () {
    for (final index in [0, -1]) {
      expect(
        () => _guideline(stepIndex: index),
        throwsA(isA<ArgumentError>()),
      );
    }
  });

  test('there is no result asset to build', () {
    // V3 generates no intermediate makeup result. The only asset kind is the
    // guideline, so no `_result` path can be constructed.
    expect(TutorialV3StoragePaths.guidelineAsset, 'guideline');
    expect(_guideline(), endsWith('_guideline.png'));
  });

  group('ownership validation', () {
    bool owned(String path, {int? stepIndex}) =>
        TutorialV3StoragePaths.isOwnedAssetPath(
          path,
          userId: _user,
          analysisId: _analysis,
          sessionId: _session,
          stepIndex: stepIndex,
        );

    test('accepts a path it built', () {
      expect(owned(_guideline(stepIndex: 3), stepIndex: 3), isTrue);
    });

    test('rejects another user, analysis or session', () {
      expect(
        owned('user-2/analyses/$_analysis/tutorial-v3/$_session/step_0001_guideline.png'),
        isFalse,
      );
      expect(
        owned('$_user/analyses/other/tutorial-v3/$_session/step_0001_guideline.png'),
        isFalse,
      );
      expect(
        owned('$_user/analyses/$_analysis/tutorial-v3/other/step_0001_guideline.png'),
        isFalse,
      );
    });

    test('rejects another step', () {
      expect(owned(_guideline(stepIndex: 2), stepIndex: 3), isFalse);
    });

    test('rejects traversal and prefix tricks', () {
      // A `startsWith` check would accept all of these.
      for (final path in [
        '$_user/analyses/$_analysis/tutorial-v3/$_session/../../original/a.jpg',
        '$_user/analyses/$_analysis/tutorial-v3/$_session/nested/step_0001_guideline.png',
        '$_user/analyses/$_analysis/tutorial-v3/$_session',
        '$_user/analyses/$_analysis/original/abc.jpg',
        '$_user/analyses/$_analysis/generated/rec/preview_0001.png',
      ]) {
        expect(owned(path), isFalse, reason: 'accepted $path');
      }
    });

    test('rejects an unexpected extension', () {
      expect(
        owned('$_user/analyses/$_analysis/tutorial-v3/$_session/step_0001_guideline.svg'),
        isFalse,
      );
      for (final extension in TutorialV3StoragePaths.allowedExtensions) {
        expect(owned(_guideline(extension: extension)), isTrue);
      }
    });

    test('rejects a result-shaped file name', () {
      expect(
        owned('$_user/analyses/$_analysis/tutorial-v3/$_session/step_0001_result.png'),
        isFalse,
      );
    });
  });

  group('stepIndexOf', () {
    test('reads back the one-based index it wrote', () {
      expect(TutorialV3StoragePaths.stepIndexOf(_guideline(stepIndex: 7)), 7);
    });

    test('returns null for anything that is not a guideline path', () {
      expect(
        TutorialV3StoragePaths.stepIndexOf('$_user/analyses/$_analysis/original/a.jpg'),
        isNull,
      );
      expect(
        TutorialV3StoragePaths.stepIndexOf(
          '$_user/analyses/$_analysis/tutorial-v3/$_session/step_0000_guideline.png',
        ),
        isNull,
      );
    });
  });
}
