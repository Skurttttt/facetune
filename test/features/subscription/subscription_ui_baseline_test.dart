import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Subscription UI baseline lock (SUB-UI-7).
///
/// The productionized paywall is built entirely from the Global UI: theme
/// tokens, shared primitives, semantic roles. These checks read the touched
/// presentation sources and refuse the ways that alignment quietly erodes —
/// a hex literal "just for this card", a `fontSize:` "just for the price", a
/// shadow, a second gradient, a hand-rolled button or spinner. They are the
/// SUB-UI-7 frontend audit, kept as a test so it runs on every change instead
/// of once.
///
/// Behaviour and layout are covered by the widget tests beside this file;
/// this file covers *vocabulary*.
String _pathOf(String relativePath) =>
    relativePath.replaceAll('/', Platform.pathSeparator);

/// Source with comments and doc comments removed and line endings normalised,
/// so a rule about code cannot be tripped by prose describing the rule.
String _codeOf(String relativePath) {
  final raw = File(_pathOf(relativePath)).readAsStringSync();
  return raw
      .replaceAll('\r\n', '\n')
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');
}

const _presentationRoot = 'lib/features/subscription/presentation';

/// Every presentation file the productionization touched.
const _touched = [
  '$_presentationRoot/pages/subscription_page.dart',
  '$_presentationRoot/widgets/subscription_plan_card.dart',
  '$_presentationRoot/widgets/subscription_summary_card.dart',
  '$_presentationRoot/widgets/ai_look_allowance_notice.dart',
  '$_presentationRoot/utils/plan_presentation.dart',
  'lib/shared/widgets/surfaces/app_card.dart',
];

void main() {
  group('Subscription UI speaks only the Global UI', () {
    test('no hardcoded colour', () {
      for (final file in _touched) {
        final code = _codeOf(file);
        expect(code, isNot(contains('Color(0x')), reason: file);
        // The one permitted fixed-ground foreground: white on the page
        // lead's rose gradient, which keeps its own brightness in both
        // themes exactly as the Auth and Home heroes do. Nothing else.
        final colours = RegExp(
          r'\bColors\.(\w+)',
        ).allMatches(code).map((m) => m.group(1)).toSet();
        expect(
          colours.difference({'white'}),
          isEmpty,
          reason: '$file uses raw Colors.* beyond the fixed-ground white',
        );
        if (colours.contains('white')) {
          expect(
            file,
            endsWith('subscription_page.dart'),
            reason: 'only the page lead draws on a fixed ground',
          );
        }
      }
    });

    test('no hardcoded type size — every style is a theme role', () {
      for (final file in _touched) {
        final code = _codeOf(file);
        expect(code, isNot(contains('fontSize:')), reason: file);
        expect(code, isNot(contains('TextStyle(fontSize')), reason: file);
        expect(code, isNot(contains('GoogleFonts')), reason: file);
        expect(code, isNot(contains('fontFamily:')), reason: file);
      }
    });

    test('no shadow, no glow, one permitted gradient', () {
      for (final file in _touched) {
        final code = _codeOf(file);
        expect(code, isNot(contains('BoxShadow')), reason: file);
        expect(code, isNot(contains('boxShadow')), reason: file);
        expect(code, isNot(contains('elevation:')), reason: file);
        expect(code, isNot(contains('BackdropFilter')), reason: file);
        expect(code, isNot(contains('ImageFilter')), reason: file);
      }
      // Exactly one gradient on the page, and it is the existing recipe.
      final page = _codeOf('$_presentationRoot/pages/subscription_page.dart');
      expect('LinearGradient('.allMatches(page).length, 1);
      expect(page, contains('colors: [AppColors.roseDark, AppColors.rose]'));
      for (final file in _touched.where((f) => !f.endsWith('page.dart'))) {
        expect(_codeOf(file), isNot(contains('Gradient(')), reason: file);
      }
    });

    test('ordinary spacing, radii and motion come from tokens', () {
      final literalSpacing = RegExp(
        r'(SizedBox\((height|width): [0-9]|EdgeInsets\.\w+\([^)]*[^\w.][0-9]|BorderRadius\.circular\([0-9]|(?<!App)Duration\(|(?<!App)Curves\.)',
      );
      for (final file in _touched) {
        final code = _codeOf(file);
        final hits = literalSpacing.allMatches(code).map((m) => m.group(0));
        expect(
          hits,
          isEmpty,
          reason: '$file: use AppSpacing / AppRadii / AppDurations / AppCurves',
        );
      }
    });

    test('no raw Material button or spinner — shared primitives only', () {
      const rawWidgets = [
        'TextButton(',
        'TextButton.icon(',
        'ElevatedButton(',
        'FilledButton(',
        'FilledButton.icon(',
        'OutlinedButton(',
        'CircularProgressIndicator(',
        'LinearProgressIndicator(',
        'FittedBox(',
      ];
      for (final file in _touched) {
        final code = _codeOf(file);
        for (final raw in rawWidgets) {
          expect(code, isNot(contains(raw)), reason: '$file must not use $raw');
        }
      }
    });

    test('critical copy is never clipped', () {
      for (final file in _touched) {
        final code = _codeOf(file);
        expect(code, isNot(contains('TextOverflow.ellipsis')), reason: file);
        expect(code, isNot(contains('maxLines:')), reason: file);
        expect(code, isNot(contains('softWrap: false')), reason: file);
      }
    });

    test('no device, platform or size conditionals in layout', () {
      for (final file in _touched) {
        final code = _codeOf(file);
        expect(code, isNot(contains('Platform.')), reason: file);
        expect(
          code,
          isNot(contains('MediaQuery.of(context).size')),
          reason: file,
        );
        expect(code, isNot(contains('MediaQuery.sizeOf')), reason: file);
        expect(code, isNot(contains('POCO')), reason: file);
        expect(code, isNot(contains('LayoutBuilder')), reason: file);
      }
    });

    test('reduced motion is honoured wherever the page animates', () {
      for (final file in [
        '$_presentationRoot/pages/subscription_page.dart',
        '$_presentationRoot/widgets/subscription_plan_card.dart',
      ]) {
        final code = _codeOf(file);
        if (code.contains('AnimatedSwitcher(') ||
            code.contains('AnimatedSize(')) {
          expect(
            code,
            contains('MediaQuery.disableAnimationsOf(context)'),
            reason: '$file animates without checking reduced motion',
          );
        }
      }
    });

    test('presentation still cannot reach billing, entitlement or secrets', () {
      const forbidden = [
        'package:in_app_purchase',
        'package:supabase',
        'functions.invoke',
        'reserve_ai_look',
        'commit_ai_look',
        'release_ai_look',
        'user_entitlements',
        'isPremium',
        'SERVICE_ROLE',
      ];
      for (final file in _touched) {
        final code = _codeOf(file);
        for (final token in forbidden) {
          expect(code, isNot(contains(token)), reason: '$file names $token');
        }
      }
    });

    test('no Subscription-specific design system exists', () {
      final presentation = Directory(_pathOf(_presentationRoot))
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final file in presentation) {
        final code = file.readAsStringSync().replaceAll('\r\n', '\n');
        for (final parallel in [
          'SubscriptionColors',
          'SubscriptionSpacing',
          'SubscriptionTypography',
          'SubscriptionRadii',
          'SubscriptionButtonTheme',
          'PremiumTheme',
          'SalonTheme',
          'SubscriptionTheme',
        ]) {
          expect(code, isNot(contains(parallel)), reason: file.path);
        }
      }
    });
  });
}
