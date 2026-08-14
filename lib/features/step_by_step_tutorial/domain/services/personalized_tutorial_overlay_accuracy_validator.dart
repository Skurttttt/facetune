import '../entities/personalized_tutorial.dart';
import '../entities/tutorial_face_geometry.dart';
import '../entities/tutorial_placement_metadata.dart';
import '../entities/tutorial_step_category.dart';

enum TutorialOverlayValidationIssue {
  confidenceTooLow,
  incompatibleRegion,
  incorrectSide,
  implausibleProximity,
  implausibleArrow,
  implausibleSize,
  inconsistentBilateralGeometry,
}

class TutorialOverlayValidationResult {
  const TutorialOverlayValidationResult({
    required this.renderableSpec,
    required this.issues,
    required this.usedMediumConfidenceFallback,
  });

  final PersonalizedTutorialStepSpec? renderableSpec;
  final List<TutorialOverlayValidationIssue> issues;
  final bool usedMediumConfidenceFallback;

  bool get canRender => renderableSpec != null;
}

/// Validates personalized overlay geometry before any drawing occurs.
/// Invalid or low-confidence data fails closed; it never selects generic
/// coordinates or pretends that an approximate path is precise.
abstract final class PersonalizedTutorialOverlayAccuracyValidator {
  static TutorialOverlayValidationResult validate(
    PersonalizedTutorialStepSpec spec,
  ) {
    final issues = <TutorialOverlayValidationIssue>{};
    final confidence = spec.where.geometryConfidence;
    if (confidence == TutorialPlacementConfidence.low ||
        confidence == TutorialPlacementConfidence.unavailable) {
      return const TutorialOverlayValidationResult(
        renderableSpec: null,
        issues: [TutorialOverlayValidationIssue.confidenceTooLow],
        usedMediumConfidenceFallback: false,
      );
    }

    _validateCompatibility(spec, issues);
    _validateAnchors(spec, issues);
    _validateBilateral(spec, issues);
    _validateArrows(spec, issues);
    if (issues.isNotEmpty) {
      return TutorialOverlayValidationResult(
        renderableSpec: null,
        issues: List.unmodifiable(issues),
        usedMediumConfidenceFallback: false,
      );
    }

    if (confidence == TutorialPlacementConfidence.medium) {
      return TutorialOverlayValidationResult(
        renderableSpec: _mediumFallback(spec),
        issues: const [],
        usedMediumConfidenceFallback: true,
      );
    }
    return TutorialOverlayValidationResult(
      renderableSpec: spec,
      issues: const [],
      usedMediumConfidenceFallback: false,
    );
  }

  static void _validateCompatibility(
    PersonalizedTutorialStepSpec spec,
    Set<TutorialOverlayValidationIssue> issues,
  ) {
    final allowed = _allowedRegions[spec.what.category] ?? const {};
    if (spec.where.regions.any((region) => !allowed.contains(region)) ||
        spec.where.overlays.any(
          (overlay) => !allowed.contains(overlay.region),
        )) {
      issues.add(TutorialOverlayValidationIssue.incompatibleRegion);
    }
  }

  static void _validateAnchors(
    PersonalizedTutorialStepSpec spec,
    Set<TutorialOverlayValidationIssue> issues,
  ) {
    for (final anchor in spec.where.geometryAnchors) {
      final center = _center(anchor.points);
      if ((anchor.side == TutorialGeometrySide.left && center.x >= 0.5) ||
          (anchor.side == TutorialGeometrySide.right && center.x <= 0.5)) {
        issues.add(TutorialOverlayValidationIssue.incorrectSide);
      }
      if (!_isNearExpectedRegion(anchor.region, center)) {
        issues.add(TutorialOverlayValidationIssue.implausibleProximity);
      }
      final xs = anchor.points.map((point) => point.x);
      final ys = anchor.points.map((point) => point.y);
      final width = xs.reduce(_max) - xs.reduce(_min);
      final height = ys.reduce(_max) - ys.reduce(_min);
      final extent = width > height ? width : height;
      final maximum = anchor.region == TutorialPlacementRegion.fullFace
          ? 1.0
          : 0.55;
      if (extent > maximum || (anchor.points.length > 1 && extent < 0.005)) {
        issues.add(TutorialOverlayValidationIssue.implausibleSize);
      }
    }
  }

  static void _validateBilateral(
    PersonalizedTutorialStepSpec spec,
    Set<TutorialOverlayValidationIssue> issues,
  ) {
    for (final region in _bilateralRegions) {
      if (!spec.where.regions.contains(region)) continue;
      final anchors = spec.where.geometryAnchors
          .where((anchor) => anchor.region == region)
          .toList(growable: false);
      final left = anchors
          .where((anchor) => anchor.side == TutorialGeometrySide.left)
          .firstOrNull;
      final right = anchors
          .where((anchor) => anchor.side == TutorialGeometrySide.right)
          .firstOrNull;
      if (left == null || right == null) {
        issues.add(
          TutorialOverlayValidationIssue.inconsistentBilateralGeometry,
        );
        continue;
      }
      final leftCenter = _center(left.points);
      final rightCenter = _center(right.points);
      if ((leftCenter.y - rightCenter.y).abs() > 0.12 ||
          leftCenter.x >= rightCenter.x) {
        issues.add(
          TutorialOverlayValidationIssue.inconsistentBilateralGeometry,
        );
      }
    }
  }

  static void _validateArrows(
    PersonalizedTutorialStepSpec spec,
    Set<TutorialOverlayValidationIssue> issues,
  ) {
    final hasArrow = spec.where.overlays.any(
      (overlay) => overlay.type == TutorialPlacementOverlayType.arrow,
    );
    if (hasArrow && spec.how.direction == TutorialDirection.none) {
      issues.add(TutorialOverlayValidationIssue.implausibleArrow);
    }
  }

  static PersonalizedTutorialStepSpec _mediumFallback(
    PersonalizedTutorialStepSpec spec,
  ) {
    final seenArrowRegions = <TutorialPlacementRegion>{};
    final overlays = <PersonalizedTutorialOverlay>[];
    for (final overlay in spec.where.overlays) {
      if (overlay.type == TutorialPlacementOverlayType.arrow) {
        if (!seenArrowRegions.add(overlay.region)) continue;
        overlays.add(overlay);
      } else {
        overlays.add(
          PersonalizedTutorialOverlay(
            type: TutorialPlacementOverlayType.zone,
            region: overlay.region,
            colorHex: overlay.colorHex,
          ),
        );
      }
    }
    return PersonalizedTutorialStepSpec(
      stepNumber: spec.stepNumber,
      what: spec.what,
      where: PersonalizedTutorialWhere(
        description: spec.where.description,
        regions: spec.where.regions,
        side: spec.where.side,
        geometryConfidence: TutorialPlacementConfidence.medium,
        placementConfidence: spec.where.placementConfidence,
        overlays: overlays,
        geometryAnchors: [
          for (final anchor in spec.where.geometryAnchors) _broaden(anchor),
        ],
      ),
      how: spec.how,
      faceAdjustment: spec.faceAdjustment,
      styleAdjustment: spec.styleAdjustment,
    );
  }

  static PersonalizedTutorialGeometryAnchor _broaden(
    PersonalizedTutorialGeometryAnchor anchor,
  ) {
    final center = _center(anchor.points);
    final points = anchor.points.length == 1
        ? [
            TutorialNormalizedPoint(
              x: (center.x - 0.035).clamp(0, 1),
              y: (center.y - 0.035).clamp(0, 1),
            ),
            TutorialNormalizedPoint(
              x: (center.x + 0.035).clamp(0, 1),
              y: (center.y + 0.035).clamp(0, 1),
            ),
          ]
        : [
            for (final point in anchor.points)
              TutorialNormalizedPoint(
                x: (center.x + (point.x - center.x) * 1.25).clamp(0, 1),
                y: (center.y + (point.y - center.y) * 1.25).clamp(0, 1),
              ),
          ];
    return PersonalizedTutorialGeometryAnchor(
      region: anchor.region,
      side: anchor.side,
      points: points,
    );
  }

  static bool _isNearExpectedRegion(
    TutorialPlacementRegion region,
    TutorialNormalizedPoint center,
  ) {
    final yRange = switch (region) {
      TutorialPlacementRegion.fullFace => (0.0, 1.0),
      TutorialPlacementRegion.forehead => (0.05, 0.4),
      TutorialPlacementRegion.underEye ||
      TutorialPlacementRegion.eyelid ||
      TutorialPlacementRegion.crease ||
      TutorialPlacementRegion.innerEye ||
      TutorialPlacementRegion.outerEye ||
      TutorialPlacementRegion.lashLine ||
      TutorialPlacementRegion.brow => (0.15, 0.58),
      TutorialPlacementRegion.temple => (0.1, 0.6),
      TutorialPlacementRegion.cheek ||
      TutorialPlacementRegion.cheekbone => (0.35, 0.75),
      TutorialPlacementRegion.nose => (0.25, 0.7),
      TutorialPlacementRegion.jaw => (0.6, 0.92),
      TutorialPlacementRegion.chin => (0.65, 0.95),
      TutorialPlacementRegion.lips => (0.5, 0.9),
    };
    return center.y >= yRange.$1 && center.y <= yRange.$2;
  }

  static TutorialNormalizedPoint _center(
    List<TutorialNormalizedPoint> points,
  ) => TutorialNormalizedPoint(
    x: points.fold<double>(0, (sum, point) => sum + point.x) / points.length,
    y: points.fold<double>(0, (sum, point) => sum + point.y) / points.length,
  );

  static double _min(double left, double right) => left < right ? left : right;
  static double _max(double left, double right) => left > right ? left : right;

  static const _bilateralRegions = {
    TutorialPlacementRegion.underEye,
    TutorialPlacementRegion.eyelid,
    TutorialPlacementRegion.crease,
    TutorialPlacementRegion.innerEye,
    TutorialPlacementRegion.outerEye,
    TutorialPlacementRegion.lashLine,
    TutorialPlacementRegion.brow,
    TutorialPlacementRegion.temple,
    TutorialPlacementRegion.cheek,
    TutorialPlacementRegion.cheekbone,
  };

  static const _allowedRegions = {
    TutorialStepCategory.foundation: {TutorialPlacementRegion.fullFace},
    TutorialStepCategory.concealer: {
      TutorialPlacementRegion.underEye,
      TutorialPlacementRegion.nose,
      TutorialPlacementRegion.forehead,
      TutorialPlacementRegion.chin,
    },
    TutorialStepCategory.contour: {
      TutorialPlacementRegion.temple,
      TutorialPlacementRegion.cheekbone,
      TutorialPlacementRegion.jaw,
      TutorialPlacementRegion.nose,
    },
    TutorialStepCategory.blush: {
      TutorialPlacementRegion.cheek,
      TutorialPlacementRegion.cheekbone,
    },
    TutorialStepCategory.highlighter: {
      TutorialPlacementRegion.cheekbone,
      TutorialPlacementRegion.nose,
      TutorialPlacementRegion.forehead,
      TutorialPlacementRegion.chin,
      TutorialPlacementRegion.lips,
    },
    TutorialStepCategory.eyeshadow: {
      TutorialPlacementRegion.eyelid,
      TutorialPlacementRegion.crease,
      TutorialPlacementRegion.innerEye,
      TutorialPlacementRegion.outerEye,
    },
    TutorialStepCategory.eyeliner: {
      TutorialPlacementRegion.lashLine,
      TutorialPlacementRegion.outerEye,
    },
    TutorialStepCategory.eyebrow: {TutorialPlacementRegion.brow},
    TutorialStepCategory.lipstick: {TutorialPlacementRegion.lips},
    TutorialStepCategory.lipGloss: {TutorialPlacementRegion.lips},
    TutorialStepCategory.finalLook: <TutorialPlacementRegion>{},
  };
}
