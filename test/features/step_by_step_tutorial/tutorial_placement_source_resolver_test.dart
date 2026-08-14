import 'package:facetune/features/step_by_step_tutorial/domain/services/tutorial_placement_source_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('step 1 always reuses the original selfie', () {
    final path = TutorialPlacementSourceResolver.resolve(
      stepNumber: 1,
      originalImagePath: 'user-1/analyses/a1/original/img.jpg',
      previousStepResultPath: 'ignored/because/step/is/one.png',
    );

    expect(path, 'user-1/analyses/a1/original/img.jpg');
  });

  test('step 1 does not require a previous step result path', () {
    final path = TutorialPlacementSourceResolver.resolve(
      stepNumber: 1,
      originalImagePath: 'user-1/analyses/a1/original/img.jpg',
    );

    expect(path, 'user-1/analyses/a1/original/img.jpg');
  });

  test('step N reuses step N-1\'s result path', () {
    final path = TutorialPlacementSourceResolver.resolve(
      stepNumber: 4,
      originalImagePath: 'user-1/analyses/a1/original/img.jpg',
      previousStepResultPath:
          'user-1/analyses/a1/tutorials/s1/step_0003_result.png',
    );

    expect(path, 'user-1/analyses/a1/tutorials/s1/step_0003_result.png');
  });

  test('step N without a previous result path throws', () {
    expect(
      () => TutorialPlacementSourceResolver.resolve(
        stepNumber: 2,
        originalImagePath: 'user-1/analyses/a1/original/img.jpg',
      ),
      throwsArgumentError,
    );
  });

  test('a step number below 1 throws', () {
    expect(
      () => TutorialPlacementSourceResolver.resolve(
        stepNumber: 0,
        originalImagePath: 'user-1/analyses/a1/original/img.jpg',
      ),
      throwsArgumentError,
    );
  });
}
