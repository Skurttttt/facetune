import 'package:facetune/features/analysis/domain/entities/facial_attributes.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_finish.dart';
import 'package:facetune/features/tutorial_v3/data/models/tutorial_v3_step_spec_codec.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_category.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_source_mode.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_step_spec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_v3_fixtures.dart';

TutorialV3StepSpec _roundTrip(TutorialV3StepSpec spec) =>
    TutorialV3StepSpecCodec.decode(
      spec: TutorialV3StepSpecCodec.encodeSpec(spec),
      productSnapshot: TutorialV3StepSpecCodec.encodeProductSnapshot(spec),
    );

void main() {
  group('round trip', () {
    test('a guideline step survives encode and decode', () {
      final original = guidelineStep(
        stepIndex: 3,
        category: TutorialV3Category.eyeshadow,
        coverage: 'Medium',
        intensity: 'Soft',
        amount: 'A light sweep',
        toolSuggestion: 'Fluffy brush',
        personalizedTip: 'Build slowly.',
        avoid: 'Do not drag toward the nose.',
      );

      final decoded = _roundTrip(original);
      expect(decoded, isA<TutorialV3GuidelineStepSpec>());
      final step = decoded as TutorialV3GuidelineStepSpec;

      expect(step.stepIndex, original.stepIndex);
      expect(step.category, original.category);
      expect(step.sourceMode, original.sourceMode);
      expect(step.selectedStyleCode, original.selectedStyleCode);
      expect(step.planVersion, original.planVersion);
      expect(step.targetReferenceMode, original.targetReferenceMode);
      expect(step.whereToApply, original.whereToApply);
      expect(step.direction, original.direction);
      expect(step.technique, original.technique);
      expect(step.coverage, original.coverage);
      expect(step.intensity, original.intensity);
      expect(step.amount, original.amount);
      expect(step.toolSuggestion, original.toolSuggestion);
      expect(step.personalizedTip, original.personalizedTip);
      expect(step.avoid, original.avoid);
      expect(step.faceRationale, original.faceRationale);
      expect(step.targetRationale, original.targetRationale);
      expect(step.targetLookCues, original.targetLookCues);
      expect(
        step.guidelineVisualIntent.description,
        original.guidelineVisualIntent.description,
      );
      expect(
        step.guidelineVisualIntent.graphics,
        original.guidelineVisualIntent.graphics,
      );
    });

    test('every category survives a round trip', () {
      for (final category in TutorialV3Category.guidelineCategories) {
        final decoded = _roundTrip(guidelineStep(category: category));
        expect(decoded.category, category, reason: '${category.code} drifted');
      }
    });

    test('the final look survives encode and decode', () {
      final original = finalLookStep(stepIndex: 5);
      final decoded = _roundTrip(original);

      expect(decoded, isA<TutorialV3FinalLookStepSpec>());
      final step = decoded as TutorialV3FinalLookStepSpec;
      expect(step.stepIndex, 5);
      expect(step.category, TutorialV3Category.finalLook);
      expect(step.targetRationale, original.targetRationale);
    });

    test('scoped facial attributes survive a round trip', () {
      final original = guidelineStep(category: TutorialV3Category.foundation);
      final decoded =
          _roundTrip(original) as TutorialV3GuidelineStepSpec;

      expect(decoded.relevantFaceAttributes.skinTone, SkinTone.medium);
      expect(decoded.relevantFaceAttributes.undertone, Undertone.warm);
      expect(decoded.relevantFaceAttributes.faceShape, isNull);
      expect(
        decoded.relevantFaceAttributes.presentAttributes,
        original.relevantFaceAttributes.presentAttributes,
      );
    });

    test('a Kit product snapshot survives a round trip', () {
      final original = guidelineStep(
        sourceMode: TutorialV3SourceMode.makeupKit,
      );
      final decoded =
          _roundTrip(original) as TutorialV3GuidelineStepSpec;

      expect(decoded.productSnapshot, isNotNull);
      expect(decoded.productSnapshot!.productId, testOwnedProductId);
      expect(decoded.productSnapshot!.isOwnedProduct, isTrue);
      expect(decoded.productSnapshot!.color!.value, '#B86F72');
      expect(decoded.productSnapshot!.finish, MakeupKitFinish.satin);
      expect(
        decoded.productSnapshot!.category,
        original.productSnapshot!.category,
      );
    });

    test('a step with no product decodes with no product', () {
      final decoded =
          _roundTrip(guidelineStep(omitProductSnapshot: true))
              as TutorialV3GuidelineStepSpec;
      expect(decoded.productSnapshot, isNull);
    });
  });

  group('the product snapshot is stored once', () {
    test('the spec payload never embeds the product', () {
      final encoded = TutorialV3StepSpecCodec.encodeSpec(
        guidelineStep(sourceMode: TutorialV3SourceMode.makeupKit),
      );
      expect(encoded.containsKey('product_snapshot'), isFalse);
      expect(encoded.containsKey('product_id'), isFalse);
    });

    test('the final look encodes no product snapshot', () {
      expect(
        TutorialV3StepSpecCodec.encodeProductSnapshot(finalLookStep()),
        isNull,
      );
    });
  });

  group('strict decoding', () {
    Map<String, Object?> encoded([TutorialV3StepSpec? spec]) =>
        TutorialV3StepSpecCodec.encodeSpec(spec ?? guidelineStep());

    test('rejects a V1 or V2 plan version rather than reinterpreting it', () {
      for (final legacy in [1, 2]) {
        final row = encoded()..['plan_version'] = legacy;
        expect(
          () => TutorialV3StepSpecCodec.decode(spec: row),
          throwsA(isA<FormatException>()),
          reason: 'plan version $legacy must be rejected',
        );
      }
    });

    test('rejects an unknown category', () {
      final row = encoded()..['category'] = 'foundation_result';
      expect(
        () => TutorialV3StepSpecCodec.decode(spec: row),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an unknown source mode, graphic or target mode', () {
      expect(
        () => TutorialV3StepSpecCodec.decode(
          spec: encoded()..['source_mode'] = 'geometry',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => TutorialV3StepSpecCodec.decode(
          spec: encoded()..['target_reference_mode'] = 'redrawn_crop',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => TutorialV3StepSpecCodec.decode(
          spec: encoded()
            ..['guideline_visual_intent'] = {
              'description': 'Finished blush applied.',
              'graphics': ['finished_makeup'],
            },
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an unsupported facial attribute value', () {
      final row = encoded()..['face_attributes'] = {'face_shape': 'rhombus'};
      expect(
        () => TutorialV3StepSpecCodec.decode(spec: row),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a missing required instruction field', () {
      for (final key in [
        'where_to_apply',
        'direction',
        'technique',
        'face_rationale',
        'target_rationale',
      ]) {
        final row = encoded()..remove(key);
        expect(
          () => TutorialV3StepSpecCodec.decode(spec: row),
          throwsA(isA<FormatException>()),
          reason: '$key must be required',
        );
      }
    });

    test('rejects a final look that carries a product', () {
      expect(
        () => TutorialV3StepSpecCodec.decode(
          spec: encoded(finalLookStep()),
          productSnapshot: const {'category': 'blush'},
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('facial attribute codes match the analysis DTO spelling', () {
    // These are read back against a persisted analysis, so a second spelling
    // here would make a stored step unreadable.
    final encoded = TutorialV3StepSpecCodec.encodeSpec(
      guidelineStep(category: TutorialV3Category.foundation),
    );
    expect(encoded['face_attributes'], {
      'skin_tone': 'medium',
      'undertone': 'warm',
    });

    final eyes = TutorialV3StepSpecCodec.encodeSpec(
      guidelineStep(category: TutorialV3Category.eyeliner),
    );
    expect(eyes['face_attributes'], {'eye_shape': 'almond'});
  });
}
