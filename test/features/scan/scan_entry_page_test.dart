import 'package:facetune/core/constants/app_constants.dart';
import 'package:facetune/features/analysis/domain/entities/face_analysis.dart';
import 'package:facetune/features/analysis/domain/repositories/face_analysis_repository.dart';
import 'package:facetune/features/analysis/domain/usecases/analyze_face.dart';
import 'package:facetune/features/analysis/presentation/controllers/face_analysis_controller.dart';
import 'package:facetune/features/scan/data/providers/image_validation_repository_provider.dart';
import 'package:facetune/features/scan/data/providers/selfie_repository_provider.dart';
import 'package:facetune/features/scan/domain/entities/local_image_validation.dart';
import 'package:facetune/features/scan/domain/entities/prepared_selfie.dart';
import 'package:facetune/features/scan/domain/entities/selfie_source.dart';
import 'package:facetune/features/scan/domain/repositories/image_validation_repository.dart';
import 'package:facetune/features/scan/domain/repositories/selfie_repository.dart';
import 'package:facetune/features/scan/presentation/controllers/scan_controller.dart';
import 'package:facetune/features/scan/presentation/pages/scan_page.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:facetune/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The New Scan acquisition screen: the state before a photo exists.
///
/// Everything here is about the choice between camera and gallery. The states
/// past that choice — a selected photo, a rejected photo, a failed analysis —
/// keep their own scrolling layout and their own tests; these assert that the
/// entry point stops behaving like an instruction form.

const _localValidation = LocalImageValidation(
  mimeType: 'image/jpeg',
  width: 1024,
  height: 1365,
  originalSizeBytes: 2048,
  uploadSizeBytes: 1024,
);

/// Never returns a selfie, so the screen stays in the acquisition state.
class _IdleSelfies implements SelfieRepository {
  int acquireCalls = 0;

  @override
  Future<PreparedSelfie?> acquire(SelfieSource source) async {
    acquireCalls += 1;
    return null;
  }

  @override
  Future<PreparedSelfie> prepareCaptured(String path) =>
      throw UnimplementedError();

  @override
  Future<bool> openPermissionSettings() async => true;

  @override
  Future<void> discard(PreparedSelfie selfie) async {}
}

class _IdleValidation implements ImageValidationRepository {
  @override
  Future<LocalImageValidation> validateLocal(PreparedSelfie selfie) async =>
      _localValidation;
}

/// The cost instrument. Nothing this screen does may move it.
class _CountingAnalysis implements FaceAnalysisRepository {
  int calls = 0;

  @override
  Future<FaceAnalysis> analyze({
    required PreparedSelfie selfie,
    required LocalImageValidation localValidation,
    required void Function(AnalysisProgress progress) onProgress,
  }) {
    calls += 1;
    throw StateError('The acquisition screen must not analyse anything.');
  }
}

class _Harness {
  const _Harness({
    required this.selfies,
    required this.analysis,
    required this.themeMode,
  });

  final _IdleSelfies selfies;
  final _CountingAnalysis analysis;
  final ValueNotifier<ThemeMode> themeMode;
}

/// The POCO X3 GT's logical size, which is the device this phase targets.
const _poco = Size(393, 873);

Future<_Harness> _pumpScanEntry(
  WidgetTester tester, {
  Size size = _poco,
  double textScale = 1,
  ThemeMode themeMode = ThemeMode.light,
  Brightness platformBrightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.platformBrightnessTestValue = platformBrightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  final selfies = _IdleSelfies();
  final analysisRepository = _CountingAnalysis();
  final analysisController = FaceAnalysisController(
    AnalyzeFace(analysisRepository),
  );
  final scanController = ScanController(
    selfieRepository: selfies,
    validationRepository: _IdleValidation(),
    analysis: analysisController,
  );
  final activeThemeMode = ValueNotifier(themeMode);
  addTearDown(activeThemeMode.dispose);

  final router = GoRouter(
    initialLocation: AppConstants.scanRoute,
    routes: <RouteBase>[
      GoRoute(
        path: AppConstants.scanRoute,
        builder: (context, state) => const ScanPage(),
      ),
      GoRoute(
        path: AppConstants.liveScanRoute,
        builder: (context, state) =>
            const Scaffold(body: Text('Live scan route')),
      ),
      GoRoute(
        path: AppConstants.analysisRoute,
        builder: (context, state) =>
            const Scaffold(body: Text('Analysis route')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        selfieRepositoryProvider.overrideWithValue(selfies),
        imageValidationRepositoryProvider.overrideWithValue(_IdleValidation()),
        faceAnalysisControllerProvider.overrideWith(
          (ref) => analysisController,
        ),
        scanControllerProvider.overrideWith((ref) => scanController),
      ],
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: activeThemeMode,
          builder: (context, mode, _) => MaterialApp.router(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: mode,
            routerConfig: router,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(
    selfies: selfies,
    analysis: analysisRepository,
    themeMode: activeThemeMode,
  );
}

Finder _takePhoto() => find.widgetWithText(PrimaryButton, 'Take a photo');
Finder _gallery() => find.byKey(const ValueKey('gallery-choose'));

/// Whether the two acquisition buttons share a row.
bool _sideBySide(WidgetTester tester) {
  final photo = tester.getRect(_takePhoto());
  final gallery = tester.getRect(_gallery());
  return (photo.center.dy - gallery.center.dy).abs() < 1;
}

void main() {
  group('the screen still says what it always said', () {
    testWidgets('the global top bar and title are untouched', (tester) async {
      await _pumpScanEntry(tester);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.appBar, isA<FaceTuneTopBar>());
      expect(find.text('New scan'), findsOneWidget);
    });

    testWidgets('the intro leads, in one heading and one line', (tester) async {
      await _pumpScanEntry(tester);

      expect(find.text("Let's find your best look."), findsOneWidget);
      expect(
        find.text('Use a clear, front-facing photo in natural light.'),
        findsOneWidget,
      );
      // The longer wording it replaced.
      expect(
        find.text('Use a clear, front-facing photo in soft natural light.'),
        findsNothing,
      );
    });

    testWidgets('the guide asks to be used, and claims nothing', (
      tester,
    ) async {
      await _pumpScanEntry(tester);

      expect(find.text('Center your face in the guide'), findsOneWidget);
      expect(find.text('Center your face in the frame'), findsNothing);

      // This screen looks at no pixels. Any of these would be a lie about what
      // it is doing, and a promise the next screen has to keep.
      for (final claim in <String>[
        'Face detected',
        'Face centered',
        'Face aligned',
        'Analyzing',
        'Scanning',
      ]) {
        expect(find.textContaining(claim), findsNothing, reason: claim);
      }
    });
  });

  group('guidance stopped taking the screen', () {
    testWidgets('the permanent five-row card is gone from the page', (
      tester,
    ) async {
      await _pumpScanEntry(tester);

      expect(find.text('For the best result'), findsNothing);
      for (final rule in <String>[
        'One person only',
        'Good, even lighting',
        'Avoid heavy blur',
        'Avoid extreme angles',
      ]) {
        expect(find.text(rule), findsNothing, reason: rule);
      }
    });

    testWidgets('two compact lines carry the same requirements', (
      tester,
    ) async {
      await _pumpScanEntry(tester);

      expect(find.text('One person · Face fully visible'), findsOneWidget);
      expect(
        find.text('Even lighting · Clear, front-facing photo'),
        findsOneWidget,
      );
    });

    testWidgets('the middot is spoken as a sentence break', (tester) async {
      // A screen reader announces "·" as nothing at all, which would run two
      // requirements into one phrase.
      await _pumpScanEntry(tester);

      final line = tester.widget<Text>(
        find.text('One person · Face fully visible'),
      );
      expect(line.semanticsLabel, 'One person. Face fully visible.');
    });

    testWidgets('Photo tips is present and quieter than the actions', (
      tester,
    ) async {
      await _pumpScanEntry(tester);

      expect(find.byKey(const ValueKey('photo-tips')), findsOneWidget);
      expect(find.text('Photo tips'), findsOneWidget);
      // Tertiary, not another button competing with the two that matter.
      expect(
        find.ancestor(
          of: find.text('Photo tips'),
          matching: find.byType(TertiaryButton),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });
  });

  group('Photo tips', () {
    testWidgets('opens the app sheet carrying all five rules', (tester) async {
      final harness = await _pumpScanEntry(tester);

      await tester.tap(find.byKey(const ValueKey('photo-tips')));
      await tester.pumpAndSettle();

      expect(find.text('For the best result'), findsOneWidget);
      for (final rule in <String>[
        'One person only',
        'Face fully visible',
        'Good, even lighting',
        'Avoid heavy blur',
        'Avoid extreme angles',
      ]) {
        expect(find.text(rule), findsOneWidget, reason: rule);
      }
      // Reading the rules is not an acquisition.
      expect(harness.analysis.calls, 0);
      expect(harness.selfies.acquireCalls, 0);
    });

    testWidgets('closes and leaves the screen exactly as it was', (
      tester,
    ) async {
      final harness = await _pumpScanEntry(tester);

      await tester.tap(find.byKey(const ValueKey('photo-tips')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TertiaryButton, 'Close'));
      await tester.pumpAndSettle();

      expect(find.text('For the best result'), findsNothing);
      expect(find.text('Avoid extreme angles'), findsNothing);
      expect(_takePhoto(), findsOneWidget);
      expect(_gallery(), findsOneWidget);
      expect(harness.analysis.calls, 0);
      expect(harness.selfies.acquireCalls, 0);
    });
  });

  group('the two ways into a photo', () {
    testWidgets('both are present, with the right emphasis', (tester) async {
      await _pumpScanEntry(tester);

      expect(_takePhoto(), findsOneWidget);
      expect(_gallery(), findsOneWidget);
      // Take a photo is filled; gallery is outlined. Not the same rung.
      expect(tester.widget(_gallery()), isA<SecondaryButton>());
    });

    testWidgets('they share a height and clear the accessible minimum', (
      tester,
    ) async {
      await _pumpScanEntry(tester);

      final photo = tester.getSize(_takePhoto());
      final gallery = tester.getSize(_gallery());
      expect(photo.height, gallery.height);
      expect(photo.height, greaterThanOrEqualTo(44));
    });

    testWidgets('they sit side by side once both labels fit', (tester) async {
      // Widget tests render with Flutter's square test font, where every glyph
      // is as wide as the font is tall — roughly twice real Roboto. The
      // crossover width here is therefore wider than a device's; what this
      // pins is that the row arrangement exists and is chosen by measurement.
      await _pumpScanEntry(tester, size: const Size(1000, 900));

      expect(_sideBySide(tester), isTrue);
      // Equal halves.
      final photo = tester.getRect(_takePhoto());
      final gallery = tester.getRect(_gallery());
      expect(photo.width, closeTo(gallery.width, 0.5));
      expect(gallery.left - photo.right, closeTo(12, 0.5));
    });

    testWidgets('they stack rather than let a label wrap', (tester) async {
      await _pumpScanEntry(tester, size: const Size(320, 900));

      expect(_sideBySide(tester), isFalse);
      // Primary first when stacked.
      expect(
        tester.getRect(_takePhoto()).top,
        lessThan(tester.getRect(_gallery()).top),
      );
    });

    testWidgets('width follows need when equal halves would not fit', (
      tester,
    ) async {
      // Wide enough for one row, not wide enough for the longer label to fit
      // half of it. §34 prefers a balanced row over a mathematically equal one,
      // and this is the case that distinguishes them.
      await _pumpScanEntry(tester, size: const Size(640, 900));

      expect(_sideBySide(tester), isTrue);
      final photo = tester.getRect(_takePhoto());
      final gallery = tester.getRect(_gallery());
      // The longer label gets the larger share, and it is a share — not a
      // takeover.
      expect(gallery.width, greaterThan(photo.width));
      expect(gallery.width, lessThan(photo.width * 2));
      expect(find.text('Choose from gallery'), findsOneWidget);
    });

    testWidgets(
      'a row too tight for the long wording shortens it, not stacks',
      (tester) async {
        await _pumpScanEntry(tester, size: const Size(560, 900));

        expect(_sideBySide(tester), isTrue);
        expect(find.text('Choose gallery'), findsOneWidget);
        expect(find.text('Choose from gallery'), findsNothing);
      },
    );

    testWidgets('a stacked button that can afford the full wording uses it', (
      tester,
    ) async {
      await _pumpScanEntry(tester);

      expect(_sideBySide(tester), isFalse);
      expect(find.text('Choose from gallery'), findsOneWidget);
    });

    testWidgets('the wording shortens only when the width demands it', (
      tester,
    ) async {
      // Narrow enough that even a full-width button cannot hold the long form.
      // The shorter label is the alternative to a wrapped one, not a default.
      await _pumpScanEntry(tester, size: const Size(320, 900));

      expect(find.text('Choose from gallery'), findsNothing);
      expect(find.text('Choose gallery'), findsOneWidget);
    });

    testWidgets('no label wraps or is clipped in either arrangement', (
      tester,
    ) async {
      for (final size in <Size>[
        const Size(320, 900),
        _poco,
        const Size(560, 900),
        const Size(640, 900),
        const Size(1000, 900),
      ]) {
        await _pumpScanEntry(tester, size: size);

        for (final button in <Finder>[_takePhoto(), _gallery()]) {
          final label = find.descendant(
            of: button,
            matching: find.byType(Text),
          );
          final text = tester.widget<Text>(label);
          expect(
            text.overflow,
            isNot(TextOverflow.ellipsis),
            reason: 'no truncation at $size',
          );
          // One line, not two. Compared against the label's own font size
          // rather than a TextPainter: a painter reports the font's natural
          // line box, and the test environment's font does not have the same
          // one the device does. What does not vary is that a second line
          // roughly doubles the height, so anything under 1.6 line boxes is
          // one line under either font.
          final element = tester.element(label);
          final fontSize =
              Theme.of(element).textTheme.labelLarge?.fontSize ?? 14;
          final oneLineCeiling =
              MediaQuery.textScalerOf(element).scale(fontSize) * 1.6;
          expect(
            tester.getSize(label).height,
            lessThan(oneLineCeiling),
            reason: 'label "${text.data}" wrapped at $size',
          );
        }
        expect(tester.takeException(), isNull, reason: '$size');
      }
    });

    testWidgets('the callbacks are the ones that already existed', (
      tester,
    ) async {
      final harness = await _pumpScanEntry(tester);

      await tester.tap(_takePhoto());
      await tester.pumpAndSettle();
      expect(find.text('Live scan route'), findsOneWidget);
      expect(harness.analysis.calls, 0);
    });

    testWidgets('gallery still runs the one-shot acquisition', (tester) async {
      final harness = await _pumpScanEntry(tester);

      await tester.tap(_gallery());
      await tester.pumpAndSettle();

      // The picker was asked exactly once. It returned nothing here, so the
      // screen stays put and nothing paid runs.
      expect(harness.selfies.acquireCalls, 1);
      expect(harness.analysis.calls, 0);
    });
  });

  group('the screen fits', () {
    testWidgets('a POCO-sized viewport needs no scrolling', (tester) async {
      await _pumpScanEntry(tester);

      // Nothing scrollable in the body at all on the normal path.
      expect(
        find.descendant(
          of: find.byType(Scaffold),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('everything the phase requires is on screen at once', (
      tester,
    ) async {
      await _pumpScanEntry(tester);
      final viewport = tester.getRect(find.byType(Scaffold).first);

      for (final finder in <Finder>[
        find.text('New scan'),
        find.text("Let's find your best look."),
        find.text('Use a clear, front-facing photo in natural light.'),
        find.text('Center your face in the guide'),
        find.text('One person · Face fully visible'),
        find.text('Photo tips'),
        _takePhoto(),
        _gallery(),
      ]) {
        final rect = tester.getRect(finder);
        expect(
          viewport.contains(rect.topLeft) &&
              viewport.contains(rect.bottomRight),
          isTrue,
          reason: 'off-screen: $finder',
        );
      }
    });

    testWidgets('the guide absorbs the spare height rather than a constant', (
      tester,
    ) async {
      // Same content, two screen heights: only the guide changes size. That is
      // what proves the layout is not built around one device.
      await _pumpScanEntry(tester, size: const Size(393, 700));
      final short = tester.getSize(find.byType(ClipRRect).first).height;
      await _pumpScanEntry(tester, size: const Size(393, 1000));
      final tall = tester.getSize(find.byType(ClipRRect).first).height;

      expect(tall, greaterThan(short + 200));
    });

    testWidgets('large text scrolls instead of clipping a control', (
      tester,
    ) async {
      await _pumpScanEntry(tester, textScale: 2);

      // The fallback: the guidance scrolls, and both actions stay in the bar
      // where they were, still reachable and still tappable.
      expect(find.byType(Scrollable), findsWidgets);
      expect(_takePhoto().hitTestable(), findsOneWidget);
      expect(_gallery().hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Nothing is hidden by the fallback — the guidance and the tips are
      // below the fold, not gone.
      await tester.scrollUntilVisible(find.text('Photo tips'), 200);
      await tester.pumpAndSettle();
      expect(find.text('Photo tips'), findsOneWidget);
    });

    testWidgets('a narrow phone at large text still shows every control', (
      tester,
    ) async {
      await _pumpScanEntry(tester, size: const Size(320, 640), textScale: 2);

      expect(_takePhoto().hitTestable(), findsOneWidget);
      expect(_gallery().hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the actions are reserved space, never an overlay', (
      tester,
    ) async {
      await _pumpScanEntry(tester);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.bottomNavigationBar, isNotNull);

      // Body content ends above the action row rather than under it.
      final guidance = tester.getRect(
        find.text('Even lighting · Clear, front-facing photo'),
      );
      expect(
        guidance.bottom,
        lessThanOrEqualTo(tester.getRect(_gallery()).top),
      );
    });
  });

  group('nothing here costs anything', () {
    testWidgets('opening, theming and rescaling stay free', (tester) async {
      final harness = await _pumpScanEntry(tester);

      await tester.tap(find.byKey(const ValueKey('photo-tips')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TertiaryButton, 'Close'));
      await tester.pumpAndSettle();

      harness.themeMode.value = ThemeMode.dark;
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(873, 393);
      await tester.pumpAndSettle();

      expect(harness.analysis.calls, 0);
      expect(harness.selfies.acquireCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in light, dark and system without overflow', (
      tester,
    ) async {
      for (final mode in <ThemeMode>[
        ThemeMode.light,
        ThemeMode.dark,
        ThemeMode.system,
      ]) {
        for (final brightness in <Brightness>[
          Brightness.light,
          Brightness.dark,
        ]) {
          final harness = await _pumpScanEntry(
            tester,
            themeMode: mode,
            platformBrightness: brightness,
          );
          expect(find.text('Center your face in the guide'), findsOneWidget);
          expect(_takePhoto(), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: 'no overflow in $mode / $brightness',
          );
          expect(harness.analysis.calls, 0);
        }
      }
    });
  });

  group('the side-by-side rule is arithmetic, not a guess', () {
    testWidgets('a button spends exactly the measured chrome on non-label', (
      tester,
    ) async {
      // The layout decides between one row and two by comparing a label's
      // measured width plus a constant against the slot it would get. If that
      // constant drifts from what Material actually charges for padding, an
      // icon and a gap, a label wraps on a real phone and no other test here
      // would notice.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: PrimaryButton(
                label: 'Take a photo',
                icon: Icons.camera_alt_outlined,
                expand: false,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      final context = tester.element(find.byType(PrimaryButton));
      final painter = TextPainter(
        text: TextSpan(
          text: 'Take a photo',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

      final chrome =
          tester.getSize(find.byType(PrimaryButton)).width - painter.width;
      expect(
        chrome,
        closeTo(66, 0.5),
        reason: 'update _AcquisitionActions._buttonChrome to match',
      );
    });
  });

  group('the face guide is as wide as the page', () {
    /// The guide's surface, located through its own caption.
    Finder guideSurface() => find.ancestor(
      of: find.text('Center your face in the guide'),
      matching: find.byType(ClipRRect),
    );

    /// A text block that already sits on the page's content gutters.
    Finder contentEdge() =>
        find.text('Use a clear, front-facing photo in natural light.');

    testWidgets(
      'it shares the content gutters, with no dead column beside it',
      (tester) async {
        // Deliberately wide. The defect was invisible on a phone under the test
        // font, because there the caption happens to be wider than the slot and
        // the surface filled by accident. Give the content more room than the
        // caption needs and a guide that sizes to its own text has nowhere to
        // hide.
        await _pumpScanEntry(tester, size: const Size(1000, 900));

        final guide = tester.getRect(guideSurface());
        final content = tester.getRect(contentEdge());
        expect(guide.left, content.left);
        expect(guide.right, content.right);
      },
    );

    testWidgets('it fills the content width on a phone too', (tester) async {
      await _pumpScanEntry(tester);

      final guide = tester.getRect(guideSurface());
      final content = tester.getRect(contentEdge());
      expect(guide.left, content.left);
      expect(guide.right, content.right);
      // And those edges are the page's own gutters, not a margin of its own.
      expect(guide.left, AppSpacing.gutter);
      expect(guide.right, _poco.width - AppSpacing.gutter);
    });

    testWidgets('the scrolling fallback keeps the same width', (tester) async {
      await _pumpScanEntry(tester, size: const Size(1000, 900), textScale: 2);

      final guide = tester.getRect(guideSurface());
      final content = tester.getRect(contentEdge());
      expect(guide.left, content.left);
      expect(guide.right, content.right);
    });

    testWidgets('its height still comes from the space left over', (
      tester,
    ) async {
      // Width is now pinned to the page; height must stay the elastic one, or
      // the fix would have traded a dead column for a fixed-height slab.
      await _pumpScanEntry(tester, size: const Size(393, 700));
      final short = tester.getSize(guideSurface()).height;
      await _pumpScanEntry(tester, size: const Size(393, 1000));
      final tall = tester.getSize(guideSurface()).height;

      expect(tall, greaterThan(short + 200));
    });

    testWidgets('it is wider than it is tall on a phone', (tester) async {
      // The proportion the width fix was for: the surface used to be as narrow
      // as its caption and taller than it was wide.
      await _pumpScanEntry(tester);

      final guide = tester.getSize(guideSurface());
      expect(guide.width, greaterThan(guide.height));
    });

    testWidgets('its mark and caption stay centred in the wider surface', (
      tester,
    ) async {
      await _pumpScanEntry(tester, size: const Size(1000, 900));

      final guide = tester.getRect(guideSurface());
      final icon = tester.getRect(find.byIcon(Icons.face_rounded));
      final caption = tester.getRect(
        find.text('Center your face in the guide'),
      );

      expect(icon.center.dx, closeTo(guide.center.dx, 1));
      expect(caption.center.dx, closeTo(guide.center.dx, 1));
      // Vertically balanced as a block rather than pinned to an edge.
      final block = Rect.fromLTRB(
        icon.left,
        icon.top,
        icon.right,
        caption.bottom,
      );
      expect(block.center.dy, closeTo(guide.center.dy, 2));
    });

    testWidgets('the icon did not grow just because the surface did', (
      tester,
    ) async {
      // Icon size follows the height it is given, not the width. A wider card
      // must not inflate it.
      await _pumpScanEntry(tester, size: const Size(393, 873));
      final onPhone = tester.getSize(find.byIcon(Icons.face_rounded)).width;
      await _pumpScanEntry(tester, size: const Size(1000, 873));
      final onWide = tester.getSize(find.byIcon(Icons.face_rounded)).width;

      expect(onWide, onPhone);
    });

    testWidgets('the gaps around it are single global steps', (tester) async {
      await _pumpScanEntry(tester);

      final guide = tester.getRect(guideSurface());
      final support = tester.getRect(contentEdge());
      final guidance = tester.getRect(
        find.text('One person · Face fully visible'),
      );

      expect(guide.top - support.bottom, AppSpacing.lg);
      expect(guidance.top - guide.bottom, AppSpacing.md);
    });
  });
}
