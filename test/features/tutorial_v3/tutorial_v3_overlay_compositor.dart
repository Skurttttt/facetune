import 'dart:ui' as ui;

import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_geometry.dart';
import 'package:facetune/features/tutorial_v3/presentation/painters/tutorial_v3_guideline_painter.dart';
import 'package:flutter/material.dart';

/// Renders geometry over an image, off-screen, for gate evidence.
///
/// **Test-only, and deliberately not in `lib/`.** It is the one place that
/// composites the overlay INTO pixels, which is precisely what the shipping
/// app must never do — there, the photograph and the overlay stay separate
/// layers in a `Stack` and the source bytes are never touched. Keeping this
/// out of the app means no screen can reach for it by accident, and the
/// "the tutorial UI writes nothing" contract can be absolute.
///
/// It uses the same painter the app uses, so what a gate inspects is what a
/// user would see.
Future<ui.Image> renderGuidelineOverlay({
  required ui.Image original,
  required TutorialV3Geometry geometry,
}) async {
  final size = Size(original.width.toDouble(), original.height.toDouble());
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  canvas.drawImage(original, Offset.zero, Paint());
  TutorialV3GuidelinePainter(
    geometry: geometry,
    imageSize: size,
    fit: BoxFit.fill,
  ).paint(canvas, size);
  return recorder.endRecording().toImage(original.width, original.height);
}
