import 'package:facetune/features/tutorial_v3/domain/value_objects/tutorial_v3_plan_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the current plan version is 3', () {
    expect(TutorialV3PlanVersion.currentValue, 3);
    expect(TutorialV3PlanVersion.current.value, 3);
  });

  test('parsing accepts only version 3', () {
    expect(TutorialV3PlanVersion.parse(3), TutorialV3PlanVersion.current);
  });

  test('a V1 or V2 row is never reinterpreted as V3', () {
    for (final legacyVersion in [0, 1, 2, 4]) {
      expect(
        () => TutorialV3PlanVersion.parse(legacyVersion),
        throwsA(isA<FormatException>()),
        reason: 'version $legacyVersion must be rejected',
      );
      expect(TutorialV3PlanVersion.tryParse(legacyVersion), isNull);
      expect(TutorialV3PlanVersion.isSupported(legacyVersion), isFalse);
    }
  });

  test('versions compare by value', () {
    expect(TutorialV3PlanVersion.parse(3), TutorialV3PlanVersion.current);
    expect(
      TutorialV3PlanVersion.parse(3).hashCode,
      TutorialV3PlanVersion.current.hashCode,
    );
    expect(TutorialV3PlanVersion.current.toString(), '3');
  });
}
