@Tags(['gate'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_category.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_geometry.dart';
import 'package:facetune/features/tutorial_v3/domain/validation/tutorial_v3_geometry_validator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_v3_overlay_compositor.dart';

/// V3-6R evidence renderer.
///
/// Not a unit test — a harness. It reads the geometry the live gate produced,
/// validates it with the REAL `TutorialV3GeometryValidator`, renders it with
/// the REAL `TutorialV3GuidelinePainter`, and writes PNGs for visual review.
/// Using the production validator and painter is the point: the evidence shows
/// what the app would actually draw.
///
/// Run explicitly:
///   flutter test test/features/tutorial_v3/tutorial_v3_geometry_render_harness.dart
///
/// It skips itself when the gate has not been run, so it never fails `flutter
/// test` for someone who has no evidence directory.
void main() {
  const gateDir = 'build/tutorial_v3_geometry_gate';

  test('renders validated geometry over the original selfie', () async {
    final directory = Directory(gateDir);
    if (!directory.existsSync()) {
      markTestSkipped('no gate evidence at $gateDir — run the geometry gate');
      return;
    }

    final originalFile = File('$gateDir/original.png');
    expect(originalFile.existsSync(), isTrue, reason: 'original.png missing');
    final originalBytes = await originalFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(originalBytes);
    final original = (await codec.getNextFrame()).image;

    final geometryFiles =
        directory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('_geometry.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    expect(geometryFiles, isNotEmpty, reason: 'no geometry JSON produced');

    final report = <String, Object?>{};
    for (final file in geometryFiles) {
      final id = file.uri.pathSegments.last.replaceAll('_geometry.json', '');
      final payload =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;

      final categoryCode = payload['category'];
      final category = categoryCode is String
          ? TutorialV3Category.fromCode(categoryCode)
          : null;
      if (category == null) {
        report[id] = {'validated': false, 'error': 'unknown category'};
        continue;
      }

      TutorialV3Geometry geometry;
      try {
        geometry = TutorialV3GeometryValidator.validate(
          payload,
          expectedCategory: category,
        );
      } catch (error) {
        report[id] = {'validated': false, 'error': '$error'};
        // A rejected document is a real result, not a harness failure: it
        // means the model produced geometry the app would refuse.
        continue;
      }

      final rendered = await renderGuidelineOverlay(
        original: original,
        geometry: geometry,
      );
      final png = await rendered.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$gateDir/${id}_overlay.png',
      ).writeAsBytes(png!.buffer.asUint8List());

      report[id] = {
        'validated': true,
        'category': category.code,
        'primitives': geometry.primitives.length,
        'roles': geometry.primitives
            .map((primitive) => '${primitive.role.code}:${primitive.kind.code}')
            .toSet()
            .toList(),
      };
    }

    await File(
      '$gateDir/render_report.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));

    // The original must be byte-identical after rendering: the harness reads
    // it and never writes to that path.
    final after = await originalFile.readAsBytes();
    expect(after.length, originalBytes.length);
    expect(after, orderedEquals(originalBytes));
  });
}
