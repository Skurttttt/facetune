import 'package:facetune/features/step_by_step_tutorial/data/models/tutorial_geometry_plan_codec.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/personalized_tutorial.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_geometry_plan.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step_category.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _validStep({
  String category = 'blush',
  Object? colorHex,
  Object? finish,
}) => {
  'category': category,
  'placement': 'Sweep across the upper cheekbones.',
  'direction': 'upwardOutward',
  'intensity': 'medium',
  'technique': 'Blend with a fluffy brush.',
  'confidence': 0.85,
  'colorHex': colorHex,
  'finish': finish,
  'zones': [
    {
      'shape': 'polygon',
      'points': [
        {'x': 0.3, 'y': 0.5},
        {'x': 0.35, 'y': 0.55},
        {'x': 0.32, 'y': 0.6},
      ],
      'confidence': 0.8,
    },
  ],
  'paths': [
    {
      'points': [
        {'x': 0.31, 'y': 0.51},
        {'x': 0.36, 'y': 0.56},
      ],
      'confidence': 0.72,
    },
  ],
  'arrows': [
    {
      'from': {'x': 0.3, 'y': 0.5},
      'to': {'x': 0.39, 'y': 0.5},
      'confidence': 0.65,
    },
  ],
};

void main() {
  group('fromJson', () {
    test('parses a complete, valid geometry plan', () {
      final plan = TutorialGeometryPlanCodec.fromJson({
        'steps': [_validStep()],
      });

      expect(plan.steps, hasLength(1));
      final step = plan.steps.single;
      expect(step.category, TutorialStepCategory.blush);
      expect(step.direction, TutorialDirection.upwardOutward);
      expect(step.intensity, TutorialIntensity.medium);
      expect(step.confidence, 0.85);
      expect(step.zones.single.shape, TutorialGeometryZoneShape.polygon);
      expect(step.zones.single.points, hasLength(3));
      expect(step.paths.single.points, hasLength(2));
      expect(step.arrows.single.from.x, 0.3);
      expect(step.arrows.single.to.x, 0.39);
    });

    test('carries a real colorHex/finish through when present', () {
      final plan = TutorialGeometryPlanCodec.fromJson({
        'steps': [_validStep(colorHex: '#E58C87', finish: 'satin')],
      });
      expect(plan.steps.single.colorHex, '#E58C87');
      expect(plan.steps.single.finish, 'satin');
    });

    test('leaves colorHex/finish null when absent, never fabricating one', () {
      final plan = TutorialGeometryPlanCodec.fromJson({
        'steps': [_validStep()],
      });
      expect(plan.steps.single.colorHex, isNull);
      expect(plan.steps.single.finish, isNull);
    });

    test('rejects a non-object root', () {
      expect(
        () => TutorialGeometryPlanCodec.fromJson([1, 2, 3]),
        throwsFormatException,
      );
    });

    test('rejects a missing steps array', () {
      expect(
        () => TutorialGeometryPlanCodec.fromJson({}),
        throwsFormatException,
      );
    });

    test('rejects an unsupported category code', () {
      expect(
        () => TutorialGeometryPlanCodec.fromJson({
          'steps': [_validStep(category: 'not_a_real_category')],
        }),
        throwsFormatException,
      );
    });

    test('rejects an out-of-range coordinate', () {
      final step = _validStep();
      step['zones'] = [
        {
          'shape': 'polygon',
          'points': [
            {'x': 1.4, 'y': 0.2},
          ],
          'confidence': 0.7,
        },
      ];
      expect(
        () => TutorialGeometryPlanCodec.fromJson({
          'steps': [step],
        }),
        throwsArgumentError,
      );
    });

    test('rejects a missing required field', () {
      final step = _validStep()..remove('technique');
      expect(
        () => TutorialGeometryPlanCodec.fromJson({
          'steps': [step],
        }),
        throwsFormatException,
      );
    });
  });
}
