import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_category.dart';
import 'package:facetune/features/tutorial_v3/presentation/painters/tutorial_v3_guideline_painter.dart';
import 'package:facetune/features/tutorial_v3/presentation/widgets/tutorial_v3_guideline_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_v3_fixtures.dart';

/// A decodable image of an exact size, so the widget resolves a real intrinsic
/// size rather than a guess.
Future<Uint8List> _pngBytes(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF8899AA),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  late Uint8List portraitBytes;
  late Uint8List tallBytes;

  // Encoding is real async work. It has to happen outside testWidgets, whose
  // fake clock never lets the codec complete.
  setUpAll(() async {
    portraitBytes = await _pngBytes(120, 160); // 3:4, a selfie's shape
    tallBytes = await _pngBytes(90, 160); // 9:16
  });

  Future<void> pump(
    WidgetTester tester, {
    required Widget child,
    Size size = const Size(300, 500),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(width: size.width, height: size.height, child: child),
        ),
      ),
    );
    // Decoding runs on the real event loop, so a plain pump is not enough:
    // runAsync lets the codec actually finish before the frame that would
    // attach the painter.
    for (var attempt = 0; attempt < 10; attempt++) {
      await tester.pump();
      if (find
          .byType(CustomPaint)
          .evaluate()
          .any(
            (element) =>
                (element.widget as CustomPaint).painter
                    is TutorialV3GuidelinePainter,
          )) {
        return;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    await tester.pump();
  }

  testWidgets('it draws the photograph', (tester) async {
    await pump(
      tester,
      child: TutorialV3GuidelineView(
        image: MemoryImage(portraitBytes),
        geometry: null,
      ),
    );

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('no overlay is attached when there is no geometry', (
    tester,
  ) async {
    // A missing guideline shows the selfie alone. Nothing is substituted.
    await pump(
      tester,
      child: TutorialV3GuidelineView(
        image: MemoryImage(portraitBytes),
        geometry: null,
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter is TutorialV3GuidelinePainter,
      ),
      findsNothing,
    );
  });

  testWidgets('the painter receives the image\'s real intrinsic size', (
    tester,
  ) async {
    await pump(
      tester,
      child: TutorialV3GuidelineView(
        image: MemoryImage(portraitBytes),
        geometry: testGeometry(),
      ),
    );

    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<TutorialV3GuidelinePainter>()
        .single;

    expect(
      painter.imageSize,
      const Size(120, 160),
      reason: 'a guessed size would misplace every primitive',
    );
  });

  testWidgets('the painter is given the same fit and alignment as the image', (
    tester,
  ) async {
    await pump(
      tester,
      child: TutorialV3GuidelineView(
        image: MemoryImage(portraitBytes),
        geometry: testGeometry(),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<TutorialV3GuidelinePainter>()
        .single;

    expect(image.fit, BoxFit.cover);
    expect(image.alignment, Alignment.topCenter);
    expect(painter.fit, image.fit);
    expect(painter.alignment, image.alignment);
  });

  testWidgets('the overlay stays aligned across screen sizes', (tester) async {
    // The same geometry on the same photograph, at three widget sizes. The
    // painter's inputs are identical every time, so the transform — which is
    // separately pinned — is what places it.
    for (final size in const [Size(280, 400), Size(360, 640), Size(600, 700)]) {
      await pump(
        tester,
        size: size,
        child: TutorialV3GuidelineView(
          image: MemoryImage(portraitBytes),
          geometry: testGeometry(category: TutorialV3Category.blush),
        ),
      );

      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((widget) => widget.painter)
          .whereType<TutorialV3GuidelinePainter>()
          .single;

      expect(painter.imageSize, const Size(120, 160), reason: 'at $size');
      expect(painter.fit, BoxFit.contain, reason: 'at $size');
    }
  });

  testWidgets('a different portrait aspect ratio is honoured', (tester) async {
    await pump(
      tester,
      child: TutorialV3GuidelineView(
        image: MemoryImage(tallBytes),
        geometry: testGeometry(),
      ),
    );

    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<TutorialV3GuidelinePainter>()
        .single;

    expect(painter.imageSize, const Size(90, 160));
  });

  testWidgets('a semantic label describes the photograph', (tester) async {
    await pump(
      tester,
      child: TutorialV3GuidelineView(
        image: MemoryImage(portraitBytes),
        geometry: testGeometry(),
        semanticLabel: 'Your photo with the guideline for this step',
      ),
    );

    expect(
      find.bySemanticsLabel('Your photo with the guideline for this step'),
      findsOneWidget,
    );
  });

  testWidgets('an unreadable image falls back rather than painting on top', (
    tester,
  ) async {
    // Drawing an overlay onto a broken image would place a guideline over
    // nothing at all.
    await pump(
      tester,
      child: TutorialV3GuidelineView(
        image: MemoryImage(Uint8List.fromList(const [1, 2, 3])),
        geometry: testGeometry(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter is TutorialV3GuidelinePainter,
      ),
      findsNothing,
    );
  });
}
