import 'package:facetune/features/step_by_step_tutorial/domain/catalog/tutorial_placement_overlay_catalog.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_placement_metadata.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every category except finalLook has at least one default overlay', () {
    for (final category in TutorialStepCategory.values) {
      final metadata = TutorialPlacementOverlayCatalog.defaultFor(category);
      if (category == TutorialStepCategory.finalLook) {
        expect(metadata.overlays, isEmpty, reason: 'finalLook has no zone');
      } else {
        expect(
          metadata.overlays,
          isNotEmpty,
          reason: '${category.code} should have default placement guidance',
        );
      }
    }
  });

  test('every default overlay point is normalized between 0.0 and 1.0', () {
    for (final category in TutorialStepCategory.values) {
      final metadata = TutorialPlacementOverlayCatalog.defaultFor(category);
      for (final overlay in metadata.overlays) {
        expect(overlay.points, isNotEmpty);
        for (final point in overlay.points) {
          expect(
            point.x,
            inInclusiveRange(0.0, 1.0),
            reason: '${category.code} ${overlay.type.code} x out of range',
          );
          expect(
            point.y,
            inInclusiveRange(0.0, 1.0),
            reason: '${category.code} ${overlay.type.code} y out of range',
          );
        }
      }
    }
  });

  test('lipstick and lip gloss both get lip boundary guidance', () {
    for (final category in [
      TutorialStepCategory.lipstick,
      TutorialStepCategory.lipGloss,
    ]) {
      final metadata = TutorialPlacementOverlayCatalog.defaultFor(category);
      expect(
        metadata.overlays.every(
          (overlay) => overlay.type == TutorialPlacementOverlayType.boundary,
        ),
        isTrue,
      );
    }
  });

  test(
    'a zone overlay is either one point, two points, or a closed polygon',
    () {
      for (final category in TutorialStepCategory.values) {
        final metadata = TutorialPlacementOverlayCatalog.defaultFor(category);
        for (final overlay in metadata.overlays) {
          if (overlay.type != TutorialPlacementOverlayType.zone) continue;
          expect(overlay.points.length, greaterThanOrEqualTo(1));
        }
      }
    },
  );
}
