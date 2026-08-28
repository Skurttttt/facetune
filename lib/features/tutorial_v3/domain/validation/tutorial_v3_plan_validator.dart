import '../../../makeup_styles/domain/catalog/makeup_style_catalog.dart';
import '../catalog/tutorial_v3_category_catalog.dart';
import '../entities/tutorial_v3_category.dart';
import '../entities/tutorial_v3_geometry_status.dart';
import '../entities/tutorial_v3_plan.dart';
import '../entities/tutorial_v3_step.dart';
import '../entities/tutorial_v3_step_spec.dart';
import '../errors/tutorial_v3_failure.dart';

/// Validates a complete tutorial plan before it is persisted.
///
/// The planner produces one plan for the whole tutorial, so this is the one
/// place that proves the plan is coherent: ordering, dynamic length, style
/// agreement, Kit ownership, attribute scoping and the terminal final-look
/// step. Guideline generation runs only against a plan that passed here, and
/// no individual generation call may relax any of these rules.
abstract final class TutorialV3PlanValidator {
  /// Validates [plan].
  ///
  /// When [ownedKitProductIds] is supplied, every Kit product referenced by
  /// the plan must be in it. Pass the caller's real owned-product set so a
  /// plan can never teach a product the user does not have.
  static void validate(
    TutorialV3Plan plan, {
    Set<String>? ownedKitProductIds,
  }) {
    final errors = <String>[];

    if (plan.steps.isEmpty) {
      throw const TutorialV3Failure(
        'A tutorial plan must contain at least one step.',
        kind: TutorialV3FailureKind.validation,
        retryable: false,
      );
    }

    if (!_isKnownStyle(plan.selectedStyleCode)) {
      errors.add('Unknown selected style "${plan.selectedStyleCode}".');
    }

    _validateTermination(plan, errors);
    _validateOrdering(plan, errors);

    for (final step in plan.steps) {
      _validateStepSpec(plan, step, ownedKitProductIds, errors);
    }

    if (errors.isNotEmpty) {
      throw TutorialV3Failure(
        errors.join(' '),
        kind: TutorialV3FailureKind.validation,
        retryable: false,
      );
    }
  }

  /// Validates the runtime state of one persisted step against its spec.
  static void validateStep(TutorialV3Step step) {
    final errors = <String>[];
    final status = step.geometryStatus;

    if (step.isFinalLook) {
      if (status != TutorialV3GeometryStatus.notRequired) {
        errors.add(
          'The final look reuses the canonical preview and must not have '
          'geometry status "${status.code}".',
        );
      }
      if (step.geometry != null) {
        errors.add('The final look must not carry mapped geometry.');
      }
    } else {
      if (status == TutorialV3GeometryStatus.notRequired) {
        errors.add('Step ${step.stepIndex} requires mapped geometry.');
      }
      if (status.expectsGeometry) {
        if (step.geometry == null) {
          errors.add('Step ${step.stepIndex} is ready but has no geometry.');
        }
      } else if (step.geometry != null) {
        errors.add(
          'Step ${step.stepIndex} carries geometry while its status is '
          '"${status.code}".',
        );
      }
      // Geometry must describe the category the step actually teaches; a
      // document for another category cannot be rendered as this one.
      final geometry = step.geometry;
      if (geometry != null && geometry.category != step.spec.category) {
        errors.add(
          'Step ${step.stepIndex} teaches "${step.spec.category.code}" but '
          'carries "${geometry.category.code}" geometry.',
        );
      }
    }

    if (step.attemptCount < 0) {
      errors.add('Step ${step.stepIndex} has a negative attempt count.');
    }

    if (errors.isNotEmpty) {
      throw TutorialV3Failure(
        errors.join(' '),
        kind: TutorialV3FailureKind.validation,
        retryable: false,
      );
    }
  }

  static void _validateTermination(TutorialV3Plan plan, List<String> errors) {
    if (plan.steps.last is! TutorialV3FinalLookStepSpec) {
      errors.add('The last step of a tutorial plan must be the final look.');
    }
    for (var index = 0; index < plan.steps.length - 1; index++) {
      if (plan.steps[index].isFinalLook) {
        errors.add(
          'The final look may only appear as the last step, not at position '
          '${index + 1}.',
        );
      }
    }
  }

  static void _validateOrdering(TutorialV3Plan plan, List<String> errors) {
    final seen = <TutorialV3Category>{};
    var previousRank = -1;

    for (var index = 0; index < plan.steps.length; index++) {
      final step = plan.steps[index];
      final expectedIndex = index + 1;

      if (step.stepIndex != expectedIndex) {
        errors.add(
          'Step at position $expectedIndex declares step index '
          '${step.stepIndex}.',
        );
      }

      if (!seen.add(step.category)) {
        errors.add('Category "${step.category.code}" appears more than once.');
      }

      final rank = TutorialV3CategoryCatalog.orderRank(step.category);
      if (rank <= previousRank) {
        errors.add(
          'Category "${step.category.code}" is out of canonical order at '
          'position $expectedIndex.',
        );
      }
      previousRank = rank;
    }
  }

  static void _validateStepSpec(
    TutorialV3Plan plan,
    TutorialV3StepSpec step,
    Set<String>? ownedKitProductIds,
    List<String> errors,
  ) {
    final position = step.stepIndex;

    if (step.planVersion != plan.planVersion) {
      errors.add(
        'Step $position declares plan version ${step.planVersion} but the '
        'plan is version ${plan.planVersion}.',
      );
    }
    if (step.sourceMode != plan.sourceMode) {
      errors.add(
        'Step $position declares source mode "${step.sourceMode.code}" but '
        'the plan is "${plan.sourceMode.code}".',
      );
    }
    if (step.selectedStyleCode != plan.selectedStyleCode) {
      errors.add(
        'Step $position declares style "${step.selectedStyleCode}" but the '
        'plan is "${plan.selectedStyleCode}".',
      );
    }
    if (!step.targetReferenceMode.isSupported) {
      errors.add(
        'Step $position uses unsupported target reference mode '
        '"${step.targetReferenceMode.code}".',
      );
    }

    switch (step) {
      case TutorialV3FinalLookStepSpec():
        if (_isBlank(step.targetRationale)) {
          errors.add('Step $position is missing a final-look rationale.');
        }
      case TutorialV3GuidelineStepSpec():
        _validateGuidelineStep(step, ownedKitProductIds, errors);
    }
  }

  static void _validateGuidelineStep(
    TutorialV3GuidelineStepSpec step,
    Set<String>? ownedKitProductIds,
    List<String> errors,
  ) {
    final position = step.stepIndex;

    void requireText(String? value, String field) {
      if (_isBlank(value)) {
        errors.add('Step $position is missing $field.');
      }
    }

    requireText(step.whereToApply, 'where to apply');
    requireText(step.direction, 'a direction');
    requireText(step.technique, 'a technique');
    requireText(step.faceRationale, 'a face rationale');
    requireText(step.targetRationale, 'a target rationale');
    requireText(step.guidelineVisualIntent.description, 'a guideline intent');

    if (step.guidelineVisualIntent.graphics.isEmpty) {
      errors.add(
        'Step $position must draw at least one instructional mark.',
      );
    }

    if (step.targetLookCues.isEmpty) {
      errors.add('Step $position is missing target look cues.');
    } else if (step.targetLookCues.any(_isBlank)) {
      errors.add('Step $position has a blank target look cue.');
    }

    _validateAttributeScope(step, errors);
    _validateProduct(step, ownedKitProductIds, errors);
  }

  static void _validateAttributeScope(
    TutorialV3GuidelineStepSpec step,
    List<String> errors,
  ) {
    final position = step.stepIndex;
    final allowed = TutorialV3CategoryCatalog.relevantAttributes(step.category);
    final present = step.relevantFaceAttributes.presentAttributes;

    final extra = present.difference(allowed);
    if (extra.isNotEmpty) {
      final names = (extra.map((a) => a.code).toList()..sort()).join(', ');
      errors.add(
        'Step $position carries facial attributes that are not relevant to '
        '"${step.category.code}": $names.',
      );
    }

    if (allowed.isNotEmpty && present.isEmpty) {
      errors.add(
        'Step $position must be personalized by at least one facial '
        'attribute relevant to "${step.category.code}".',
      );
    }
  }

  static void _validateProduct(
    TutorialV3GuidelineStepSpec step,
    Set<String>? ownedKitProductIds,
    List<String> errors,
  ) {
    final position = step.stepIndex;
    final snapshot = step.productSnapshot;

    if (snapshot != null && snapshot.category != step.category.kitCategory) {
      errors.add(
        'Step $position teaches "${step.category.code}" but snapshots a '
        '"${snapshot.category.code}" product.',
      );
    }

    if (step.sourceMode.isKit) {
      if (snapshot == null) {
        errors.add(
          'Step $position is a Kit step and must snapshot an owned product.',
        );
        return;
      }
      final productId = snapshot.productId;
      if (productId == null) {
        errors.add(
          'Step $position snapshots a product the user does not own.',
        );
        return;
      }
      if (ownedKitProductIds != null &&
          !ownedKitProductIds.contains(productId)) {
        errors.add(
          'Step $position references Kit product "$productId", which the '
          'user does not own.',
        );
      }
    } else if (snapshot?.productId != null) {
      errors.add(
        'Step $position is a standard step and must not reference an owned '
        'Kit product.',
      );
    }
  }

  static bool _isKnownStyle(String code) =>
      MakeupStyleCatalog.styles.any((style) => style.code == code);

  static bool _isBlank(String? value) => value == null || value.trim().isEmpty;
}
