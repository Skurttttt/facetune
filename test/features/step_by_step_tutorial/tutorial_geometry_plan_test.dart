import 'package:facetune/features/step_by_step_tutorial/domain/entities/personalized_tutorial.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_face_geometry.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_geometry_plan.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step_category.dart';
import 'package:flutter_test/flutter_test.dart';

TutorialNormalizedPoint _point({double x = 0.3, double y = 0.5}) =>
    TutorialNormalizedPoint(x: x, y: y);

TutorialCategoryGeometryPlan _plan({
  TutorialStepCategory category = TutorialStepCategory.blush,
  List<TutorialGeometryZone> zones = const [],
  List<TutorialGeometryPath> paths = const [],
  List<TutorialGeometryArrow> arrows = const [],
}) => TutorialCategoryGeometryPlan(
  category: category,
  placement: 'Upper cheekbones',
  direction: TutorialDirection.outward,
  intensity: TutorialIntensity.medium,
  technique: 'Blend with a fluffy brush.',
  confidence: 0.85,
  zones: zones.isEmpty && paths.isEmpty && arrows.isEmpty
      ? [
          TutorialGeometryZone(
            shape: TutorialGeometryZoneShape.polygon,
            points: [_point(), _point(x: 0.35, y: 0.55)],
            confidence: 0.8,
          ),
        ]
      : zones,
  paths: paths,
  arrows: arrows,
);

void main() {
  group('TutorialGeometryZone', () {
    test('rejects an empty point list', () {
      expect(
        () => TutorialGeometryZone(
          shape: TutorialGeometryZoneShape.polygon,
          points: const [],
          confidence: 0.8,
        ),
        throwsArgumentError,
      );
    });

    test('rejects an out-of-range confidence', () {
      expect(
        () => TutorialGeometryZone(
          shape: TutorialGeometryZoneShape.polygon,
          points: [_point()],
          confidence: 1.5,
        ),
        throwsArgumentError,
      );
    });
  });

  group('TutorialGeometryPath', () {
    test('rejects fewer than two points', () {
      expect(
        () => TutorialGeometryPath(points: [_point()], confidence: 0.7),
        throwsArgumentError,
      );
    });

    test('accepts two or more points', () {
      final path = TutorialGeometryPath(
        points: [_point(), _point(x: 0.4)],
        confidence: 0.7,
      );
      expect(path.points, hasLength(2));
    });
  });

  group('TutorialGeometryArrow', () {
    test('rejects an out-of-range confidence', () {
      expect(
        () => TutorialGeometryArrow(
          from: _point(),
          to: _point(x: 0.4),
          confidence: -0.1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('TutorialCategoryGeometryPlan', () {
    test('rejects finalLook as a category', () {
      expect(
        () => TutorialCategoryGeometryPlan(
          category: TutorialStepCategory.finalLook,
          placement: 'Complete look',
          direction: TutorialDirection.none,
          intensity: TutorialIntensity.medium,
          technique: 'Review.',
          confidence: 0.9,
          zones: [
            TutorialGeometryZone(
              shape: TutorialGeometryZoneShape.region,
              points: [_point()],
              confidence: 0.8,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects a plan with no geometry primitives at all', () {
      expect(
        () => TutorialCategoryGeometryPlan(
          category: TutorialStepCategory.blush,
          placement: 'Upper cheekbones',
          direction: TutorialDirection.outward,
          intensity: TutorialIntensity.medium,
          technique: 'Blend.',
          confidence: 0.9,
        ),
        throwsArgumentError,
      );
    });

    test('rejects an out-of-range step-level confidence', () {
      expect(
        () => TutorialCategoryGeometryPlan(
          category: TutorialStepCategory.blush,
          placement: 'Upper cheekbones',
          direction: TutorialDirection.outward,
          intensity: TutorialIntensity.medium,
          technique: 'Blend.',
          confidence: 1.2,
          zones: [
            TutorialGeometryZone(
              shape: TutorialGeometryZoneShape.polygon,
              points: [_point()],
              confidence: 0.8,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('TutorialGeometryPlan', () {
    test('rejects an empty step list', () {
      expect(() => TutorialGeometryPlan(steps: const []), throwsArgumentError);
    });

    test('rejects duplicate categories', () {
      expect(
        () => TutorialGeometryPlan(
          steps: [
            _plan(category: TutorialStepCategory.blush),
            _plan(category: TutorialStepCategory.blush),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('forCategory finds the matching entry, or null when absent', () {
      final plan = TutorialGeometryPlan(
        steps: [
          _plan(category: TutorialStepCategory.blush),
          _plan(category: TutorialStepCategory.lipstick),
        ],
      );

      expect(
        plan.forCategory(TutorialStepCategory.lipstick)?.category,
        TutorialStepCategory.lipstick,
      );
      expect(plan.forCategory(TutorialStepCategory.foundation), isNull);
    });
  });
}
