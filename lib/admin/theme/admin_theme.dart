import 'package:flutter/material.dart';

import 'admin_tokens.dart';
import 'admin_typography.dart';

/// The Web Admin's semantic colour roles, carried on the theme.
///
/// Material's [ColorScheme] has no slot for a sidebar background, a strong
/// border, a subtle selected fill, a warning, or an informational state, and
/// the console needs all five. Putting them here keeps every widget reading
/// one authority instead of reaching for a raw constant, and lets a test
/// assert that the roles exist and stay distinct.
@immutable
class AdminSemanticColors extends ThemeExtension<AdminSemanticColors> {
  const AdminSemanticColors({
    required this.pageBackground,
    required this.sidebarBackground,
    required this.surface,
    required this.surfaceSecondary,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.accent,
    required this.accentHover,
    required this.accentSubtle,
    required this.success,
    required this.warning,
    required this.danger,
    required this.information,
  });

  /// The Operational Dark SaaS roles (UI SOT section 8).
  static const dark = AdminSemanticColors(
    pageBackground: AdminColors.pageBackground,
    sidebarBackground: AdminColors.sidebarBackground,
    surface: AdminColors.surface,
    surfaceSecondary: AdminColors.surfaceSecondary,
    border: AdminColors.border,
    borderStrong: AdminColors.borderStrong,
    textPrimary: AdminColors.textPrimary,
    textSecondary: AdminColors.textSecondary,
    textDisabled: AdminColors.textDisabled,
    accent: AdminColors.accent,
    accentHover: AdminColors.accentHover,
    accentSubtle: AdminColors.accentSubtle,
    success: AdminColors.success,
    warning: AdminColors.warning,
    danger: AdminColors.error,
    information: AdminColors.information,
  );

  final Color pageBackground;
  final Color sidebarBackground;
  final Color surface;
  final Color surfaceSecondary;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color accent;
  final Color accentHover;
  final Color accentSubtle;
  final Color success;
  final Color warning;

  /// Errors and destructive actions. Named `danger` rather than `error` so a
  /// destructive *action* is never styled from the accent by habit.
  final Color danger;
  final Color information;

  /// The status roles, for assertions and for widgets that map a server
  /// status onto a colour. Status is never carried by colour alone.
  Map<String, Color> get statusRoles => {
    'success': success,
    'warning': warning,
    'danger': danger,
    'information': information,
  };

  /// Reads the roles off [context]. Falls back to [dark] so a widget tested
  /// outside the admin theme still renders.
  static AdminSemanticColors of(BuildContext context) =>
      Theme.of(context).extension<AdminSemanticColors>() ?? dark;

  @override
  AdminSemanticColors copyWith({
    Color? pageBackground,
    Color? sidebarBackground,
    Color? surface,
    Color? surfaceSecondary,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? accent,
    Color? accentHover,
    Color? accentSubtle,
    Color? success,
    Color? warning,
    Color? danger,
    Color? information,
  }) => AdminSemanticColors(
    pageBackground: pageBackground ?? this.pageBackground,
    sidebarBackground: sidebarBackground ?? this.sidebarBackground,
    surface: surface ?? this.surface,
    surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
    border: border ?? this.border,
    borderStrong: borderStrong ?? this.borderStrong,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textDisabled: textDisabled ?? this.textDisabled,
    accent: accent ?? this.accent,
    accentHover: accentHover ?? this.accentHover,
    accentSubtle: accentSubtle ?? this.accentSubtle,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    information: information ?? this.information,
  );

  @override
  AdminSemanticColors lerp(
    ThemeExtension<AdminSemanticColors>? other,
    double t,
  ) {
    if (other is! AdminSemanticColors) return this;
    Color at(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return AdminSemanticColors(
      pageBackground: at(pageBackground, other.pageBackground),
      sidebarBackground: at(sidebarBackground, other.sidebarBackground),
      surface: at(surface, other.surface),
      surfaceSecondary: at(surfaceSecondary, other.surfaceSecondary),
      border: at(border, other.border),
      borderStrong: at(borderStrong, other.borderStrong),
      textPrimary: at(textPrimary, other.textPrimary),
      textSecondary: at(textSecondary, other.textSecondary),
      textDisabled: at(textDisabled, other.textDisabled),
      accent: at(accent, other.accent),
      accentHover: at(accentHover, other.accentHover),
      accentSubtle: at(accentSubtle, other.accentSubtle),
      success: at(success, other.success),
      warning: at(warning, other.warning),
      danger: at(danger, other.danger),
      information: at(information, other.information),
    );
  }
}

/// The Web Admin's own theme (WA-13.5-UI-1).
///
/// Built entirely from `lib/admin/theme/`. It never reads
/// `lib/theme/app_theme.dart`, so nothing here can move the consumer
/// application's rendering, and the consumer theme remains free to change
/// without touching the console.
///
/// UI-1 sets colour, type and control shape only. Structure — the shell, the
/// sidebar, page headers, cards, table density — belongs to UI-2 through UI-9
/// and is deliberately not themed here.
abstract final class AdminTheme {
  /// The single Web Admin theme. The console is dark by decision, not by
  /// operating-system preference: an operations tool should look the same on
  /// every machine it is opened on.
  static ThemeData get dark {
    const semantics = AdminSemanticColors.dark;

    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AdminColors.accent,
      onPrimary: AdminColors.onAccent,
      primaryContainer: AdminColors.accentSubtle,
      onPrimaryContainer: AdminColors.textPrimary,
      secondary: AdminColors.information,
      onSecondary: AdminColors.onAccent,
      tertiary: AdminColors.success,
      onTertiary: AdminColors.onAccent,
      error: AdminColors.error,
      onError: AdminColors.onAccent,
      errorContainer: AdminColors.surfaceSecondary,
      onErrorContainer: AdminColors.error,
      surface: AdminColors.surface,
      onSurface: AdminColors.textPrimary,
      surfaceContainerLowest: AdminColors.pageBackground,
      surfaceContainerLow: AdminColors.sidebarBackground,
      surfaceContainer: AdminColors.surface,
      surfaceContainerHigh: AdminColors.surfaceSecondary,
      surfaceContainerHighest: AdminColors.surfaceSecondary,
      onSurfaceVariant: AdminColors.textSecondary,
      outline: AdminColors.border,
      outlineVariant: AdminColors.borderStrong,
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: AdminColors.textPrimary,
      onInverseSurface: AdminColors.pageBackground,
      inversePrimary: AdminColors.accentHover,
    );

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AdminRadii.control),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AdminColors.pageBackground,
      canvasColor: AdminColors.pageBackground,
      fontFamily: AdminTypography.fontFamily,
      fontFamilyFallback: AdminTypography.fontFamilyFallback,
      textTheme: AdminTypography.textTheme,
      extensions: const [semantics],
      dividerTheme: const DividerThemeData(
        color: AdminColors.border,
        thickness: AdminBorders.hairline,
        space: AdminBorders.hairline,
      ),
      iconTheme: const IconThemeData(
        color: AdminColors.textSecondary,
        size: AdminIconSizes.lg,
      ),
      cardTheme: CardThemeData(
        color: AdminColors.surface,
        elevation: AdminElevation.none,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminRadii.card),
          side: const BorderSide(color: AdminColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AdminColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: AdminElevation.dialog,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminRadii.dialog),
          side: const BorderSide(color: AdminColors.border),
        ),
        titleTextStyle: AdminTypography.sectionTitle,
        contentTextStyle: AdminTypography.tableContent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AdminColors.surfaceSecondary,
        surfaceTintColor: Colors.transparent,
        elevation: AdminElevation.popover,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminRadii.card),
          side: const BorderSide(color: AdminColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AdminColors.accent,
          foregroundColor: AdminColors.onAccent,
          disabledBackgroundColor: AdminColors.surfaceSecondary,
          disabledForegroundColor: AdminColors.textDisabled,
          textStyle: AdminTypography.button,
          shape: controlShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AdminColors.textPrimary,
          disabledForegroundColor: AdminColors.textDisabled,
          side: const BorderSide(color: AdminColors.border),
          textStyle: AdminTypography.button,
          shape: controlShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AdminColors.accent,
          disabledForegroundColor: AdminColors.textDisabled,
          textStyle: AdminTypography.button,
          shape: controlShape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AdminColors.surfaceSecondary,
        labelStyle: AdminTypography.formLabel,
        helperStyle: AdminTypography.helperText,
        hintStyle: AdminTypography.helperText,
        errorStyle: AdminTypography.helperText.copyWith(
          color: AdminColors.error,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminRadii.control),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminRadii.control),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminRadii.control),
          borderSide: const BorderSide(
            color: AdminColors.accent,
            width: AdminBorders.strong,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminRadii.control),
          borderSide: const BorderSide(color: AdminColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminRadii.control),
          borderSide: const BorderSide(
            color: AdminColors.error,
            width: AdminBorders.strong,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminRadii.control),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AdminColors.accent,
        linearTrackColor: AdminColors.surfaceSecondary,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AdminColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(AdminRadii.control),
          border: Border.all(color: AdminColors.border),
        ),
        textStyle: AdminTypography.helperText.copyWith(
          color: AdminColors.textPrimary,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(AdminColors.borderStrong),
      ),
      splashFactory: NoSplash.splashFactory,
    );
  }
}
