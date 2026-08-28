import 'package:facetune/features/tutorial_v3/domain/catalog/tutorial_v3_geometry_catalog.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_category.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_geometry.dart';
import 'package:facetune/features/tutorial_v3/domain/errors/tutorial_v3_failure.dart';
import 'package:facetune/features/tutorial_v3/domain/validation/tutorial_v3_geometry_validator.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> point(double x, double y) => {'x': x, 'y': y};

Map<String, Object?> document({
  Object? schemaVersion = tutorialV3GeometrySchemaVersion,
  Object? category = 'blush',
  Object? space = tutorialV3CoordinateSpace,
  List<Object?>? primitives,
  Map<String, Object?> extra = const {},
}) => {
  'schema_version': schemaVersion,
  'category': category,
  'coordinate_space': space,
  'primitives': primitives ?? [placementEllipse()],
  ...extra,
};

Map<String, Object?> placementEllipse({
  double cx = 0.3,
  double cy = 0.4,
  double rx = 0.08,
  double ry = 0.05,
}) => {
  'kind': 'ellipse',
  'role': 'placement_zone',
  'center': point(cx, cy),
  'radius_x': rx,
  'radius_y': ry,
};

Map<String, Object?> arrow({
  double x1 = 0.30,
  double y1 = 0.40,
  double x2 = 0.20,
  double y2 = 0.32,
}) => {
  'kind': 'arrow',
  'role': 'blend_direction',
  'start': point(x1, y1),
  'end': point(x2, y2),
};

TutorialV3Geometry validate(
  Map<String, Object?> payload, {
  TutorialV3Category category = TutorialV3Category.blush,
}) => TutorialV3GeometryValidator.validate(payload, expectedCategory: category);

Matcher throwsValidation(String messagePart) => throwsA(
  isA<TutorialV3Failure>()
      .having((f) => f.kind, 'kind', TutorialV3FailureKind.validation)
      .having((f) => f.retryable, 'retryable', isFalse)
      .having((f) => f.message, 'message', contains(messagePart)),
);

void main() {
  group('accepts valid geometry', () {
    test('a placement zone plus a direction arrow', () {
      final geometry = validate(
        document(primitives: [placementEllipse(), arrow()]),
      );
      expect(geometry.primitives, hasLength(2));
      expect(geometry.category, TutorialV3Category.blush);
      expect(geometry.isCurrentSchema, isTrue);
      expect(geometry.coordinateSpace, tutorialV3CoordinateSpace);
    });

    test('regions, polylines and markers in their allowed roles', () {
      final lip = validate(
        document(
          category: 'lipstick',
          primitives: [
            {
              'kind': 'polyline',
              'role': 'boundary',
              'vertices': [point(0.4, 0.6), point(0.5, 0.58), point(0.6, 0.6)],
            },
            {
              'kind': 'region',
              'role': 'coverage_zone',
              'vertices': [point(0.4, 0.6), point(0.6, 0.6), point(0.5, 0.65)],
            },
          ],
        ),
        category: TutorialV3Category.lipstick,
      );
      expect(lip.primitives, hasLength(2));

      final liner = validate(
        document(
          category: 'eyeliner',
          primitives: [
            {'kind': 'marker', 'role': 'focus_marker', 'position': point(0.6, 0.3)},
          ],
        ),
        category: TutorialV3Category.eyeliner,
      );
      expect(liner.primitives.single, isA<TutorialV3Marker>());
    });

    test('rotation defaults to zero when omitted', () {
      final geometry = validate(document(primitives: [placementEllipse()]));
      expect((geometry.primitives.single as TutorialV3Ellipse).rotation, 0);
    });
  });

  group('schema and context', () {
    test('rejects an unsupported schema version', () {
      expect(
        () => validate(document(schemaVersion: 2)),
        throwsValidation('Unsupported geometry schema version 2'),
      );
    });

    test('rejects a wrong coordinate space', () {
      expect(
        () => validate(document(space: 'screen_pixels')),
        throwsValidation('coordinate_space must be'),
      );
    });

    test('rejects a category mismatch', () {
      expect(
        () => validate(document(category: 'lipstick')),
        throwsValidation('category mismatch'),
      );
    });

    test('rejects an unknown category', () {
      expect(
        () => validate(document(category: 'cheekbone_glow')),
        throwsValidation('is not a known category'),
      );
    });

    test('rejects empty or missing primitives', () {
      expect(
        () => validate(document(primitives: const [])),
        throwsValidation('non-empty list'),
      );
    });
  });

  group('style, text and code fields are refused', () {
    test('rejects unexpected document fields', () {
      expect(
        () => validate(document(extra: {'svg': '<svg/>', 'label': 'Blush'})),
        throwsValidation('unsupported fields: label, svg'),
      );
    });

    test('rejects unexpected primitive fields', () {
      expect(
        () => validate(
          document(
            primitives: [
              {...placementEllipse(), 'color': '#FF0000', 'opacity': 0.4},
            ],
          ),
        ),
        throwsValidation('unsupported fields: color, opacity'),
      );
    });

    test('rejects unexpected point fields', () {
      expect(
        () => validate(
          document(
            primitives: [
              {
                'kind': 'marker',
                'role': 'focus_marker',
                'position': {'x': 0.5, 'y': 0.5, 'z': 0.1},
              },
            ],
            category: 'highlighter',
          ),
          category: TutorialV3Category.highlighter,
        ),
        throwsValidation('unsupported fields: z'),
      );
    });
  });

  group('coordinate integrity', () {
    test('rejects out-of-range coordinates without clamping', () {
      expect(
        () => validate(
          document(primitives: [placementEllipse(cx: 1.4)]),
        ),
        throwsValidation('outside the normalized 0–1 range'),
      );
      expect(
        () => validate(document(primitives: [placementEllipse(cy: -0.2)])),
        throwsValidation('outside the normalized 0–1 range'),
      );
    });

    test('rejects NaN and infinity', () {
      expect(
        () => validate(
          document(
            primitives: [
              {
                ...placementEllipse(),
                'center': {'x': double.nan, 'y': 0.5},
              },
            ],
          ),
        ),
        throwsValidation('not a finite number'),
      );
      expect(
        () => validate(
          document(
            primitives: [
              {
                ...placementEllipse(),
                'center': {'x': 0.5, 'y': double.infinity},
              },
            ],
          ),
        ),
        throwsValidation('not a finite number'),
      );
    });

    test('rejects non-numeric coordinates', () {
      expect(
        () => validate(
          document(
            primitives: [
              {
                ...placementEllipse(),
                'center': {'x': '0.5', 'y': 0.5},
              },
            ],
          ),
        ),
        throwsValidation('must be a number'),
      );
    });
  });

  group('primitive shape rules', () {
    test('rejects an unknown primitive kind', () {
      expect(
        () => validate(
          document(primitives: [
            {'kind': 'bezier', 'role': 'placement_zone'},
          ]),
        ),
        throwsValidation('unknown kind "bezier"'),
      );
    });

    test('rejects an unknown role', () {
      expect(
        () => validate(
          document(primitives: [
            {...placementEllipse(), 'role': 'sparkle_zone'},
          ]),
        ),
        throwsValidation('unknown role "sparkle_zone"'),
      );
    });

    test('rejects a region with too few vertices', () {
      expect(
        () => validate(
          document(
            primitives: [
              {
                'kind': 'region',
                'role': 'placement_zone',
                'vertices': [point(0.3, 0.4), point(0.4, 0.4)],
              },
            ],
          ),
        ),
        throwsValidation('region needs'),
      );
    });

    test('rejects a polyline with too many vertices', () {
      expect(
        () => validate(
          document(
            category: 'eyeliner',
            primitives: [
              {
                'kind': 'polyline',
                'role': 'application_path',
                'vertices': List.generate(
                  TutorialV3GeometryCatalog.maxPolylineVertices + 1,
                  (index) => point(index / 100, 0.3),
                ),
              },
            ],
          ),
          category: TutorialV3Category.eyeliner,
        ),
        throwsValidation('polyline needs'),
      );
    });

    test('rejects invalid radii', () {
      expect(
        () => validate(document(primitives: [placementEllipse(rx: 0)])),
        throwsValidation('radius_x 0.0 is outside'),
      );
      expect(
        () => validate(document(primitives: [placementEllipse(ry: 0.95)])),
        throwsValidation('radius_y 0.95 is outside'),
      );
    });

    test('rejects a zero-length arrow', () {
      expect(
        () => validate(
          document(
            primitives: [arrow(x1: 0.3, y1: 0.4, x2: 0.3, y2: 0.4)],
          ),
        ),
        throwsValidation('shows no direction'),
      );
    });

    test('rejects too many primitives', () {
      expect(
        () => validate(
          document(
            primitives: List.generate(
              TutorialV3GeometryCatalog.maxPrimitives + 1,
              (_) => placementEllipse(),
            ),
          ),
        ),
        throwsValidation('too many primitives'),
      );
    });
  });

  group('category and role compatibility', () {
    test('rejects a role the category does not allow', () {
      // A coverage zone belongs to foundation and lips, never to eyeliner.
      expect(
        () => validate(
          document(
            category: 'eyeliner',
            primitives: [
              {
                'kind': 'region',
                'role': 'coverage_zone',
                'vertices': [point(0.3, 0.3), point(0.5, 0.3), point(0.4, 0.4)],
              },
            ],
          ),
          category: TutorialV3Category.eyeliner,
        ),
        throwsValidation('does not allow'),
      );
    });

    test('rejects a kind the role does not allow', () {
      // A direction must be an arrow, not a polygon.
      expect(
        () => validate(
          document(
            primitives: [
              {
                'kind': 'region',
                'role': 'blend_direction',
                'vertices': [point(0.3, 0.3), point(0.5, 0.3), point(0.4, 0.4)],
              },
            ],
          ),
        ),
        throwsValidation('which only accepts'),
      );
    });

    test('every category has a declared role set', () {
      for (final category in TutorialV3Category.values) {
        final roles = TutorialV3GeometryCatalog.rolesFor(category);
        if (category.isFinalLook) {
          expect(roles, isEmpty, reason: 'the final look draws no geometry');
        } else {
          expect(roles, isNotEmpty, reason: '${category.code} has no roles');
        }
      }
    });

    test('every role maps to at least one primitive kind', () {
      for (final role in TutorialV3GeometryRole.values) {
        expect(TutorialV3GeometryCatalog.kindsFor(role), isNotEmpty);
      }
    });
  });

  group('no image or code path exists', () {
    test('the geometry contract carries no image or style fields', () {
      // Asserted structurally: a document is exactly these four keys, and a
      // primitive exposes only shape and role.
      final geometry = validate(document(primitives: [placementEllipse()]));
      final primitive = geometry.primitives.single;
      expect(primitive.role, TutorialV3GeometryRole.placementZone);
      expect(primitive.kind, TutorialV3PrimitiveKind.ellipse);
      expect(primitive.points, hasLength(1));
    });
  });
}
