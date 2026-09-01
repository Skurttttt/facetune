import 'dart:io';

import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:facetune/features/tutorial/presentation/utils/tutorial_image_focus.dart';
import 'package:facetune/features/tutorial/presentation/widgets/tutorial_final_look_card.dart';
import 'package:facetune/features/tutorial/presentation/widgets/tutorial_image_viewer.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The V4-QA-5 viewing experience, in isolation from a tutorial session.
///
/// Everything here is presentation over an artifact the app already holds. No
/// repository is involved and none is faked, which is itself part of what these
/// prove: a viewer that needed a repository would be a viewer that could
/// generate something.
Future<void> _pumpViewer(
  WidgetTester tester,
  Widget child, {
  ThemeMode themeMode = ThemeMode.light,
  Brightness systemBrightness = Brightness.light,
  Size size = const Size(393, 873),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.platformBrightnessTestValue = systemBrightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: inner!,
      ),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('category-aware focus', () {
    test('every category maps to a focus', () {
      for (final category in TutorialCategory.values) {
        expect(TutorialImageFocus.forCategory(category), isNotNull);
      }
    });

    test('small-feature categories open zoomed, complexion does not', () {
      const zoomed = <TutorialCategory>[
        TutorialCategory.eyebrows,
        TutorialCategory.eyeshadow,
        TutorialCategory.eyeliner,
        TutorialCategory.lips,
        TutorialCategory.blush,
      ];
      const whole = <TutorialCategory>[
        TutorialCategory.foundation,
        TutorialCategory.concealer,
        TutorialCategory.contourBronzer,
        // Spread across brow bone, nose, cheekbone and Cupid's bow, so any
        // single zoom would hide most of the points.
        TutorialCategory.highlighter,
      ];
      for (final category in zoomed) {
        expect(
          TutorialImageFocus.forCategory(category).isZoomed,
          isTrue,
          reason: '${category.code} has a small feature worth zooming to',
        );
      }
      for (final category in whole) {
        expect(
          TutorialImageFocus.forCategory(category),
          TutorialImageFocus.wholeFace,
          reason: '${category.code} needs the whole face',
        );
      }
    });

    test('the eye categories look higher than the mouth category', () {
      expect(
        TutorialImageFocus.forCategory(TutorialCategory.eyeliner).alignment.y,
        lessThan(
          TutorialImageFocus.forCategory(TutorialCategory.lips).alignment.y,
        ),
      );
    });

    test('no focus zooms far enough to lose the face', () {
      // A starting zoom is a convenience, not a crop. Past roughly 2x on a 3:4
      // portrait there is no surrounding face left to orient by, and a framing
      // this mapping guessed wrong would strand the user.
      for (final focus in TutorialImageFocus.values) {
        expect(focus.scale, lessThanOrEqualTo(2));
        expect(focus.scale, greaterThanOrEqualTo(1));
      }
    });
  });

  group('the full-screen viewer', () {
    testWidgets('shows the image it was given, whole', (tester) async {
      await _pumpViewer(
        tester,
        const TutorialImageViewer(
          url: 'https://example.invalid/guide.png',
          title: 'Eyeliner',
          semanticLabel: 'Guideline markings',
        ),
      );

      final image = tester.widget<PrivateImage>(find.byType(PrivateImage));
      expect(image.url, 'https://example.invalid/guide.png');
      expect(
        image.fit,
        BoxFit.contain,
        reason: 'cropping a guideline to fill the screen would hide marks',
      );
      expect(
        image.decodeMultiplier,
        greaterThan(1),
        reason: 'a zoomed guideline must not go soft',
      );
      expect(find.text('Eyeliner'), findsOneWidget);
    });

    testWidgets('the whole image stays reachable at any zoom', (tester) async {
      await _pumpViewer(
        tester,
        const TutorialImageViewer(
          url: 'https://example.invalid/guide.png',
          title: 'Eyeliner',
          semanticLabel: 'Guideline markings',
          focus: TutorialImageFocus.eyes,
        ),
      );

      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      expect(
        viewer.minScale,
        lessThanOrEqualTo(1),
        reason: 'the user can always get back to the full frame',
      );
      expect(viewer.maxScale, greaterThan(1));
      expect(
        viewer.constrained,
        isTrue,
        reason: 'the image cannot be flung off-screen and lost',
      );
    });

    // Two tests rather than one, because pumping a second viewer of the same
    // type into the same tree reuses the first one's State — and with it the
    // first one's transform, which would make the second assertion a lie.
    testWidgets('an eye focus opens zoomed in on the eyes', (tester) async {
      await _pumpViewer(
        tester,
        const TutorialImageViewer(
          url: 'https://example.invalid/guide.png',
          title: 'Eyeliner',
          semanticLabel: 'Guideline markings',
          focus: TutorialImageFocus.eyes,
        ),
      );

      final transform = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!
          .value;
      expect(transform.getMaxScaleOnAxis(), greaterThan(1));
      expect(
        transform.getTranslation().y,
        greaterThan(0),
        reason: 'the view moves down the image to bring the eyes to centre',
      );
    });

    testWidgets('a whole-face focus opens untransformed', (tester) async {
      await _pumpViewer(
        tester,
        const TutorialImageViewer(
          url: 'https://example.invalid/final.png',
          title: 'Your final look',
          semanticLabel: 'Your final look',
        ),
      );

      expect(
        tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController!
            .value,
        Matrix4.identity(),
      );
    });

    testWidgets('the reset control appears only once the view has moved', (
      tester,
    ) async {
      await _pumpViewer(
        tester,
        const TutorialImageViewer(
          url: 'https://example.invalid/guide.png',
          title: 'Eyeliner',
          semanticLabel: 'Guideline markings',
          focus: TutorialImageFocus.eyes,
        ),
      );
      expect(find.byTooltip('Reset view'), findsNothing);

      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      controller.value = Matrix4.identity()..scaleByDouble(3, 3, 1, 1);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Reset view'), findsOneWidget);

      await tester.tap(find.byTooltip('Reset view'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Reset view'), findsNothing);
    });

    testWidgets('it never paints its own black or white page', (tester) async {
      for (final (mode, brightness) in <(ThemeMode, Brightness)>[
        (ThemeMode.light, Brightness.light),
        (ThemeMode.dark, Brightness.dark),
        (ThemeMode.system, Brightness.dark),
        (ThemeMode.system, Brightness.light),
      ]) {
        await _pumpViewer(
          tester,
          const TutorialImageViewer(
            url: 'https://example.invalid/guide.png',
            title: 'Eyeliner',
            semanticLabel: 'Guideline markings',
          ),
          themeMode: mode,
          systemBrightness: brightness,
        );

        final context = tester.element(find.byType(InteractiveViewer));
        final scheme = Theme.of(context).colorScheme;
        final scaffold = tester.widget<Scaffold>(
          find.descendant(
            of: find.byType(TutorialImageViewer),
            matching: find.byType(Scaffold),
          ),
        );
        expect(
          scaffold.backgroundColor,
          scheme.surface,
          reason: 'the viewer follows the global theme like every other page',
        );
        expect(scaffold.backgroundColor, isNot(Colors.black));
        expect(scaffold.backgroundColor, isNot(Colors.white));
      }
    });

    testWidgets('it survives a narrow screen at large text', (tester) async {
      await _pumpViewer(
        tester,
        const TutorialImageViewer(
          url: 'https://example.invalid/guide.png',
          title: 'Contour & Bronzer',
          semanticLabel: 'Guideline markings',
        ),
        size: const Size(320, 640),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the final-look reference', () {
    testWidgets('the compact form names what it is and how to open it', (
      tester,
    ) async {
      await _pumpViewer(
        tester,
        const TutorialFinalLookCard(url: 'https://example.invalid/final.png'),
      );

      expect(find.text('Your final look'), findsOneWidget);
      expect(
        find.text('The finished result you are working toward'),
        findsOneWidget,
      );
      expect(
        tester.widget<PrivateImage>(find.byType(PrivateImage)).url,
        'https://example.invalid/final.png',
      );
    });

    testWidgets('the expanded form shows the same single artifact', (
      tester,
    ) async {
      await _pumpViewer(
        tester,
        const TutorialFinalLookCard(
          url: 'https://example.invalid/final.png',
          expanded: true,
        ),
      );

      expect(find.text('Your final look'), findsOneWidget);
      final images = tester.widgetList<PrivateImage>(find.byType(PrivateImage));
      expect(images.length, 1, reason: 'one canonical preview, rendered once');
      expect(images.first.url, 'https://example.invalid/final.png');
    });

    testWidgets('both forms fit a narrow screen at large text', (tester) async {
      for (final expanded in <bool>[false, true]) {
        await _pumpViewer(
          tester,
          TutorialFinalLookCard(
            url: 'https://example.invalid/final.png',
            expanded: expanded,
          ),
          size: const Size(320, 640),
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('show/hide guidelines is not faked', () {
    final root = Directory.current;

    String source(String relativePath) => File(
      '${root.path}${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}',
    ).readAsStringSync();

    test('the guideline is one flattened image, with no separable layer', () {
      // The gate V4-QA-5 requires before any toggle may exist. The renderer
      // returns a single edited raster and the step persists a single path, so
      // there is nothing to hide: no alpha overlay, no vector guides, no second
      // artifact. A toggle would have to fake it, so none was built.
      final prompt = source(
        'supabase/functions/generate-tutorial-step-v4/prompt.ts',
      );
      expect(prompt, contains('Return exactly one edited image.'));

      final step = source(
        'lib/features/tutorial/domain/entities/tutorial_step.dart',
      );
      expect(step, contains('guidelineStoragePath'));
      for (final absent in <String>[
        'overlayStoragePath',
        'guideLayerPath',
        'guidesVisible',
      ]) {
        expect(
          step,
          isNot(contains(absent)),
          reason: 'a separable guide layer does not exist',
        );
      }
    });

    test('no widget offers a guide visibility or opacity control', () {
      final page = source(
        'lib/features/tutorial/presentation/pages/tutorial_page.dart',
      );
      final viewer = source(
        'lib/features/tutorial/presentation/widgets/tutorial_image_viewer.dart',
      );
      for (final faked in <String>[
        'hideGuides',
        'showGuides',
        'guideOpacity',
        'Hide guides',
        'Show guides',
        'Opacity(',
      ]) {
        expect(
          page + viewer,
          isNot(contains(faked)),
          reason: 'a control that cannot work must not be offered',
        );
      }
    });
  });
}
