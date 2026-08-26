import 'package:facetune/features/step_by_step_tutorial/domain/entities/personalized_tutorial.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_face_geometry.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_generation_status.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_geometry_plan.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_instruction.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_placement_metadata.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step_category.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/services/tutorial_geometry_activation.dart';
import 'package:flutter_test/flutter_test.dart';

TutorialNormalizedPoint _point(double x, double y) =>
    TutorialNormalizedPoint(x: x, y: y);

TutorialStep _step({
  TutorialStepCategory category = TutorialStepCategory.blush,
  TutorialPlacementMetadata? placementMetadata,
}) => TutorialStep(
  id: 'step-1',
  tutorialSessionId: 'session-1',
  stepNumber: 1,
  category: category,
  title: 'Blush',
  instruction: TutorialInstruction(
    category: category,
    placement: 'Upper cheekbones',
    intensity: 'light',
    technique: 'Blend upward.',
  ),
  placementMetadata: placementMetadata,
  generationStatus: TutorialStepGenerationStatus.notStarted,
  createdAt: DateTime.utc(2026, 8, 14),
  updatedAt: DateTime.utc(2026, 8, 14),
);

TutorialCategoryGeometryPlan _categoryPlan({
  TutorialStepCategory category = TutorialStepCategory.blush,
  double confidence = 0.85,
  String? colorHex,
  List<TutorialGeometryZone> zones = const [],
  List<TutorialGeometryPath> paths = const [],
  List<TutorialGeometryArrow> arrows = const [],
}) => TutorialCategoryGeometryPlan(
  category: category,
  placement: 'Upper cheekbones',
  direction: TutorialDirection.outward,
  intensity: TutorialIntensity.medium,
  technique: 'Blend with a fluffy brush.',
  confidence: confidence,
  colorHex: colorHex,
  zones: zones.isEmpty && paths.isEmpty && arrows.isEmpty
      ? [
          TutorialGeometryZone(
            shape: TutorialGeometryZoneShape.polygon,
            points: [_point(0.3, 0.5), _point(0.35, 0.55), _point(0.32, 0.6)],
            confidence: confidence,
          ),
        ]
      : zones,
  paths: paths,
  arrows: arrows,
);

void main() {
  group('category primitives', () {
    test('a zone primitive becomes a zone overlay with matching points', () {
      final plan = TutorialGeometryPlan(steps: [_categoryPlan()]);
      final activated = TutorialGeometryActivation.applyToStep(_step(), plan);

      final overlay = activated.placementMetadata!.overlays.single;
      expect(overlay.type, TutorialPlacementOverlayType.zone);
      expect(overlay.points, hasLength(3));
    });

    test('a path primitive becomes a line overlay', () {
      final plan = TutorialGeometryPlan(
        steps: [
          _categoryPlan(
            category: TutorialStepCategory.eyeliner,
            paths: [
              TutorialGeometryPath(
                points: [_point(0.2, 0.4), _point(0.3, 0.4)],
                confidence: 0.9,
              ),
            ],
          ),
        ],
      );
      final activated = TutorialGeometryActivation.applyToStep(
        _step(category: TutorialStepCategory.eyeliner),
        plan,
      );

      final overlay = activated.placementMetadata!.overlays.single;
      expect(overlay.type, TutorialPlacementOverlayType.line);
      expect(overlay.points, hasLength(2));
    });

    test('an arrow primitive becomes an arrow overlay with two points', () {
      final plan = TutorialGeometryPlan(
        steps: [
          _categoryPlan(
            category: TutorialStepCategory.contour,
            arrows: [
              TutorialGeometryArrow(
                from: _point(0.2, 0.5),
                to: _point(0.3, 0.5),
                confidence: 0.9,
              ),
            ],
          ),
        ],
      );
      final activated = TutorialGeometryActivation.applyToStep(
        _step(category: TutorialStepCategory.contour),
        plan,
      );

      final overlay = activated.placementMetadata!.overlays.single;
      expect(overlay.type, TutorialPlacementOverlayType.arrow);
      expect(overlay.points, hasLength(2));
      expect(overlay.points[0].x, 0.2);
      expect(overlay.points[0].y, 0.5);
      expect(overlay.points[1].x, 0.3);
      expect(overlay.points[1].y, 0.5);
    });

    test('covers every named category (Foundation through Lips) with a real '
        'overlay, not a category-specific hardcoded catalog', () {
      for (final category in TutorialStepCategory.values) {
        if (category == TutorialStepCategory.finalLook) continue;
        final plan = TutorialGeometryPlan(
          steps: [_categoryPlan(category: category)],
        );
        final activated = TutorialGeometryActivation.applyToStep(
          _step(category: category),
          plan,
        );
        expect(
          activated.placementMetadata!.overlays,
          isNotEmpty,
          reason: category.code,
        );
      }
    });

    test(
      'a product color is carried onto zone/line overlays, never invented',
      () {
        final plan = TutorialGeometryPlan(
          steps: [_categoryPlan(colorHex: '#E58C87')],
        );
        final activated = TutorialGeometryActivation.applyToStep(_step(), plan);
        expect(
          activated.placementMetadata!.overlays.single.colorHex,
          '#E58C87',
        );
      },
    );
  });

  group('confidence behavior', () {
    test('low confidence renders nothing — no false precision', () {
      final plan = TutorialGeometryPlan(
        steps: [_categoryPlan(confidence: 0.3)],
      );
      final original = _step();
      final activated = TutorialGeometryActivation.applyToStep(original, plan);
      // No fake guides: an unusable category plan leaves the exact same
      // step untouched (identical instance) rather than replacing it with
      // an empty-but-different placement metadata object.
      expect(identical(activated, original), isTrue);
      expect(activated.placementMetadata, isNull);
    });

    test('medium confidence keeps at most one arrow, matching the accuracy '
        "validator's own de-duplication rule", () {
      final plan = TutorialGeometryPlan(
        steps: [
          _categoryPlan(
            confidence: 0.65,
            zones: const [],
            arrows: [
              TutorialGeometryArrow(
                from: _point(0.2, 0.5),
                to: _point(0.3, 0.5),
                confidence: 0.9,
              ),
              TutorialGeometryArrow(
                from: _point(0.6, 0.5),
                to: _point(0.7, 0.5),
                confidence: 0.9,
              ),
            ],
          ),
        ],
      );
      final activated = TutorialGeometryActivation.applyToStep(_step(), plan);

      final overlays = activated.placementMetadata!.overlays;
      expect(
        overlays.where((o) => o.type == TutorialPlacementOverlayType.arrow),
        hasLength(1),
      );
    });

    test('high confidence keeps every confident primitive', () {
      final plan = TutorialGeometryPlan(
        steps: [
          _categoryPlan(
            confidence: 0.92,
            zones: const [],
            arrows: [
              TutorialGeometryArrow(
                from: _point(0.2, 0.5),
                to: _point(0.3, 0.5),
                confidence: 0.9,
              ),
              TutorialGeometryArrow(
                from: _point(0.6, 0.5),
                to: _point(0.7, 0.5),
                confidence: 0.9,
              ),
            ],
          ),
        ],
      );
      final activated = TutorialGeometryActivation.applyToStep(_step(), plan);

      final overlays = activated.placementMetadata!.overlays;
      expect(
        overlays.where((o) => o.type == TutorialPlacementOverlayType.arrow),
        hasLength(2),
      );
    });

    test('a primitive below the confidence floor is dropped even inside an '
        'overall-confident category', () {
      final plan = TutorialGeometryPlan(
        steps: [
          _categoryPlan(
            confidence: 0.9,
            zones: [
              TutorialGeometryZone(
                shape: TutorialGeometryZoneShape.polygon,
                points: [_point(0.3, 0.5), _point(0.35, 0.55)],
                confidence: 0.2,
              ),
            ],
          ),
        ],
      );
      final activated = TutorialGeometryActivation.applyToStep(_step(), plan);
      // The only primitive was weak enough to drop, so nothing renders --
      // no fake guides -- and the step keeps its prior (null) metadata.
      expect(activated.placementMetadata, isNull);
    });
  });

  group('normalized scaling', () {
    test(
      'points pass through unchanged -- no pixel conversion at this layer',
      () {
        final plan = TutorialGeometryPlan(
          steps: [
            _categoryPlan(
              zones: [
                TutorialGeometryZone(
                  shape: TutorialGeometryZoneShape.polygon,
                  points: [_point(0.123, 0.456), _point(0.789, 0.012)],
                  confidence: 0.9,
                ),
              ],
            ),
          ],
        );
        final activated = TutorialGeometryActivation.applyToStep(_step(), plan);

        final points = activated.placementMetadata!.overlays.single.points;
        expect(points[0].x, 0.123);
        expect(points[0].y, 0.456);
        expect(points[1].x, 0.789);
        expect(points[1].y, 0.012);
      },
    );
  });

  group('no fake guides when invalid', () {
    test('the final "complete look" step is never touched', () {
      final plan = TutorialGeometryPlan(steps: [_categoryPlan()]);
      final step = TutorialStep(
        id: 'step-final',
        tutorialSessionId: 'session-1',
        stepNumber: 2,
        category: TutorialStepCategory.finalLook,
        title: 'Final Look',
        instruction: const TutorialInstruction(
          category: TutorialStepCategory.finalLook,
          placement: 'Complete look',
          intensity: 'as applied',
          technique: 'Review.',
        ),
        generationStatus: TutorialStepGenerationStatus.notStarted,
        createdAt: DateTime.utc(2026, 8, 14),
        updatedAt: DateTime.utc(2026, 8, 14),
      );

      final activated = TutorialGeometryActivation.applyToStep(step, plan);
      expect(activated.placementMetadata, isNull);
    });

    test('a category the plan does not cover leaves the step untouched, not '
        'crashed or fabricated', () {
      final plan = TutorialGeometryPlan(
        steps: [_categoryPlan(category: TutorialStepCategory.lipstick)],
      );
      final activated = TutorialGeometryActivation.applyToStep(
        _step(category: TutorialStepCategory.blush),
        plan,
      );
      expect(activated.placementMetadata, isNull);
    });

    test('a null geometry plan leaves every step in the list untouched', () {
      final steps = [_step(), _step(category: TutorialStepCategory.lipstick)];
      expect(TutorialGeometryActivation.applyToSteps(steps, null), same(steps));
    });
  });
}
