import 'dart:io';

import 'package:facetune/admin/theme/admin_theme.dart';
import 'package:facetune/admin/theme/admin_tokens.dart';
import 'package:facetune/admin/theme/admin_typography.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WA-13.5-UI-1: the Web Admin's visual token authority.
///
/// These tests protect three properties the type system cannot express:
/// the semantic roles exist and stay distinct, a destructive action can never
/// be styled from the accent, and the console's theme is isolated from the
/// consumer application's so neither can restyle the other.
void main() {
  final root = Directory.current;

  String pathOf(String relativePath) =>
      '${root.path}${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}';

  List<File> dartFilesIn(String relativeDirectory) {
    final directory = Directory(pathOf(relativeDirectory));
    if (!directory.existsSync()) return const <File>[];
    return directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
  }

  String codeOf(File file) => file
      .readAsStringSync()
      .replaceAll('\r\n', '\n')
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  final adminFiles = [
    ...dartFilesIn('lib/admin'),
    File(pathOf('lib/admin_main.dart')),
  ];

  group('semantic roles', () {
    test('every role the console needs exists on the theme', () {
      final theme = AdminTheme.dark;
      final semantics = theme.extension<AdminSemanticColors>();

      expect(
        semantics,
        isNotNull,
        reason: 'widgets read roles from the theme, not from constants',
      );
      expect(semantics!.pageBackground, AdminColors.pageBackground);
      expect(semantics.sidebarBackground, AdminColors.sidebarBackground);
      expect(semantics.surface, AdminColors.surface);
      expect(semantics.surfaceSecondary, AdminColors.surfaceSecondary);
      expect(semantics.border, AdminColors.border);
      expect(semantics.borderStrong, AdminColors.borderStrong);
      expect(semantics.textPrimary, AdminColors.textPrimary);
      expect(semantics.textSecondary, AdminColors.textSecondary);
      expect(semantics.textDisabled, AdminColors.textDisabled);
      expect(semantics.accent, AdminColors.accent);
      expect(semantics.accentHover, AdminColors.accentHover);
      expect(semantics.accentSubtle, AdminColors.accentSubtle);
      expect(semantics.success, AdminColors.success);
      expect(semantics.warning, AdminColors.warning);
      expect(semantics.danger, AdminColors.error);
      expect(semantics.information, AdminColors.information);
    });

    test('the four status roles are present and mutually distinct', () {
      final roles = AdminSemanticColors.dark.statusRoles;

      expect(
        roles.keys,
        containsAll(<String>['success', 'warning', 'danger', 'information']),
      );
      expect(
        roles.values.toSet().length,
        roles.length,
        reason: 'two statuses sharing one colour cannot be told apart',
      );
    });

    test('the roles survive copyWith and lerp', () {
      const base = AdminSemanticColors.dark;

      expect(
        base.copyWith(danger: AdminColors.success).danger,
        AdminColors.success,
      );
      expect(base.copyWith().accent, base.accent);
      expect(base.lerp(base, 0.5).accent, base.accent);
      expect(
        base.lerp(null, 0.5).accent,
        base.accent,
        reason: 'a foreign extension must not blank the roles',
      );
    });
  });

  group('destructive is never the accent', () {
    test('danger differs from the accent and from its hover state', () {
      const semantics = AdminSemanticColors.dark;

      expect(semantics.danger, isNot(semantics.accent));
      expect(semantics.danger, isNot(semantics.accentHover));
      expect(semantics.danger, isNot(semantics.accentSubtle));
    });

    test('the scheme carries error separately from primary', () {
      final scheme = AdminTheme.dark.colorScheme;

      expect(scheme.error, AdminColors.error);
      expect(scheme.primary, AdminColors.accent);
      expect(scheme.error, isNot(scheme.primary));
    });

    test('no status role is the accent, so status is not forced to rose', () {
      for (final entry in AdminSemanticColors.dark.statusRoles.entries) {
        expect(
          entry.value,
          isNot(AdminColors.accent),
          reason: '${entry.key} must not be the action colour',
        );
        expect(entry.value, isNot(AdminColors.accentHover), reason: entry.key);
      }
    });
  });

  group('isolation from the consumer application', () {
    test('no admin source imports the consumer theme', () {
      for (final file in adminFiles) {
        final code = codeOf(file);
        expect(
          code,
          isNot(contains("theme/app_theme.dart'")),
          reason: '${file.path} must not read the consumer theme',
        );
        expect(
          code,
          isNot(contains("theme/app_tokens.dart'")),
          reason: '${file.path} must not read the consumer tokens',
        );
        expect(
          code,
          isNot(contains("theme/app_typography.dart'")),
          reason: file.path,
        );
        expect(
          code,
          isNot(contains("theme/app_semantics.dart'")),
          reason: file.path,
        );
      }
    });

    test('no admin source names a consumer token class', () {
      for (final file in adminFiles) {
        final code = codeOf(file);
        for (final symbol in const [
          'AppSpacing.',
          'AppRadii.',
          'AppColors.',
          'AppTheme.',
          'AppTypography.',
          'AppSemantics.',
        ]) {
          expect(
            code,
            isNot(contains(symbol)),
            reason: '${file.path}: $symbol',
          );
        }
      }
    });

    test('the admin theme is a different object from the consumer theme', () {
      final admin = AdminTheme.dark;

      expect(
        admin.colorScheme.primary,
        isNot(AppTheme.lightTheme.colorScheme.primary),
      );
      expect(
        admin.scaffoldBackgroundColor,
        isNot(AppTheme.lightTheme.scaffoldBackgroundColor),
      );
      expect(admin.scaffoldBackgroundColor, AdminColors.pageBackground);
    });

    test('the consumer theme carries no admin extension', () {
      expect(AppTheme.lightTheme.extension<AdminSemanticColors>(), isNull);
      expect(AppTheme.darkTheme.extension<AdminSemanticColors>(), isNull);
    });

    test('building the admin theme does not mutate the consumer theme', () {
      final beforeLight = AppTheme.lightTheme.colorScheme.primary;
      final beforeDark = AppTheme.darkTheme.colorScheme.primary;
      final beforeLightBackground = AppTheme.lightTheme.scaffoldBackgroundColor;

      AdminTheme.dark;

      expect(AppTheme.lightTheme.colorScheme.primary, beforeLight);
      expect(AppTheme.darkTheme.colorScheme.primary, beforeDark);
      expect(
        AppTheme.lightTheme.scaffoldBackgroundColor,
        beforeLightBackground,
      );
    });
  });

  group('token scales match the source of truth', () {
    test('spacing is the canonical nine-step scale', () {
      expect(
        const [
          AdminSpacing.xxs,
          AdminSpacing.xs,
          AdminSpacing.sm,
          AdminSpacing.md,
          AdminSpacing.ml,
          AdminSpacing.lg,
          AdminSpacing.xl,
          AdminSpacing.xxl,
          AdminSpacing.xxxl,
        ],
        const [4.0, 8.0, 12.0, 16.0, 20.0, 24.0, 32.0, 40.0, 48.0],
      );
    });

    test('radii are control 6, card 8, section and dialog 10', () {
      expect(AdminRadii.control, 6.0);
      expect(AdminRadii.card, 8.0);
      expect(AdminRadii.section, 10.0);
      expect(AdminRadii.dialog, 10.0);
      expect(
        AdminRadii.control,
        lessThan(AdminRadii.pill),
        reason: 'buttons are not capsules; only badges may be pills',
      );
    });

    test('controls use the control radius, not a capsule', () {
      final theme = AdminTheme.dark;
      final shape =
          theme.filledButtonTheme.style?.shape?.resolve({})
              as RoundedRectangleBorder?;

      expect(shape, isNotNull);
      expect(shape!.borderRadius, BorderRadius.circular(AdminRadii.control));
    });

    test('cards are bordered rather than elevated', () {
      final card = AdminTheme.dark.cardTheme;

      expect(card.elevation, AdminElevation.none);
      expect(card.color, AdminColors.surface);
    });
  });

  group('typography', () {
    test('the named roles carry the sizes the SOT defines', () {
      expect(AdminTypography.pageTitle.fontSize, 24);
      expect(AdminTypography.pageSubtitle.fontSize, 14);
      expect(AdminTypography.sectionTitle.fontSize, 18);
      expect(AdminTypography.cardTitle.fontSize, 13);
      expect(AdminTypography.metricValue.fontSize, 28);
      expect(AdminTypography.tableHeading.fontSize, 13);
      expect(AdminTypography.tableContent.fontSize, 14);
      expect(AdminTypography.formLabel.fontSize, 13);
      expect(AdminTypography.helperText.fontSize, 12);
      expect(AdminTypography.button.fontSize, 14);
      expect(AdminTypography.navigation.fontSize, 14);
      expect(AdminTypography.metadata.fontSize, 12);
      expect(AdminTypography.statusBadge.fontSize, 12);
    });

    test('hierarchy comes from weight, not from oversized type', () {
      expect(AdminTypography.pageTitle.fontWeight, FontWeight.w600);
      expect(AdminTypography.sectionTitle.fontWeight, FontWeight.w600);
      expect(AdminTypography.tableContent.fontWeight, FontWeight.w400);
      expect(
        AdminTypography.pageTitle.fontSize,
        lessThanOrEqualTo(AdminTypography.metricValue.fontSize!),
      );
    });

    test('no condensed display face; the stack is Inter then Roboto', () {
      final theme = AdminTheme.dark;

      expect(AdminTypography.fontFamily, 'Inter');
      expect(AdminTypography.fontFamilyFallback, const ['Roboto']);
      expect(theme.textTheme.bodyMedium?.fontSize, 14);
    });

    test('the slots the admin actually uses keep their rendered size', () {
      final text = AdminTheme.dark.textTheme;

      expect(text.headlineMedium?.fontSize, 28);
      expect(text.headlineSmall?.fontSize, 24);
      expect(text.bodyMedium?.fontSize, 14);
      expect(text.bodySmall?.fontSize, 12);
      expect(text.labelMedium?.fontSize, 13);
      expect(text.titleMedium?.fontSize, 18);
    });
  });

  group('the console is dark by decision', () {
    testWidgets('an admin surface renders on the page background', (
      tester,
    ) async {
      late BuildContext captured;

      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.dark,
          darkTheme: AdminTheme.dark,
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) {
              captured = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );

      final theme = Theme.of(captured);
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AdminColors.pageBackground);
      expect(
        AdminSemanticColors.of(captured).sidebarBackground,
        AdminColors.sidebarBackground,
      );
    });

    test('the entrypoint pins the theme instead of following the system', () {
      final source = File(
        pathOf('lib/admin/app/admin_app.dart'),
      ).readAsStringSync().replaceAll('\r\n', '\n');

      expect(source, contains('AdminTheme.dark'));
      expect(source, contains('ThemeMode.dark'));
      expect(source, isNot(contains('ThemeMode.system')));
    });
  });
}
