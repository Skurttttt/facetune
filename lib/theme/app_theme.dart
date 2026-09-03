import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import 'app_semantics.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

/// The one place FaceTune's visual language is assembled.
///
/// The rule this file exists to enforce: a screen never defines design language.
/// If a component looks a particular way on more than one screen, its appearance
/// belongs in a `ThemeData` entry here, not repeated at call sites. That is why
/// several themes below (`dividerTheme`, `chipTheme`, `listTileTheme`) were
/// added without touching a single feature file — a widget already in the tree
/// picks up its theme automatically, so consistency arrives without a rewrite.
class AppTheme {
  const AppTheme._();

  static ThemeData get lightTheme => _theme(Brightness.light);
  static ThemeData get darkTheme => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.rose,
      brightness: brightness,
      surface: isDark ? AppColors.darkSurface : AppColors.ivory,
      error: AppColors.error,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? AppColors.darkSurface : AppColors.ivory,
      fontFamily: AppTypography.fontFamily,
    );
    final text = AppTypography.apply(base.textTheme);

    // Hairline colour for every separated surface. One value, so a card border,
    // a list divider and an input outline cannot drift apart.
    final hairline = isDark ? Colors.white10 : AppColors.sand;
    final outline = isDark ? Colors.white24 : AppColors.sand;
    // Error text needs the lightened tone on a dark ground for the same reason
    // body copy does: the brand error red reaches only ~3:1 there.
    final errorText = isDark ? AppColors.errorLight : AppColors.errorDeep;
    // Resolved here as well as registered below, so component themes can be
    // built from the same roles the widgets read at runtime.
    final semantics = isDark ? AppSemantics.dark : AppSemantics.light;

    return base.copyWith(
      textTheme: text,

      // Semantic roles ride along as a ThemeExtension so they lerp with the
      // theme and resolve once, rather than being recomputed per call site.
      extensions: <ThemeExtension<dynamic>>[semantics],

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: AppElevation.none,
        scrolledUnderElevation: AppElevation.none,
        backgroundColor: Colors.transparent,
        titleTextStyle: text.titleLarge?.copyWith(
          color: isDark ? Colors.white : AppColors.cocoa,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : AppColors.cocoa,
          size: AppIconSizes.md,
        ),
        // The app bar is transparent, so the status bar sits directly on the
        // page. Android does not infer icon colour from that, so without this
        // the light theme draws white status-bar icons on the near-white ivory
        // ground and the clock and battery disappear.
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
              ),
      ),

      cardTheme: CardThemeData(
        elevation: AppElevation.none,
        color: isDark ? AppColors.darkCard : Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: hairline, width: AppBorders.hairline),
        ),
      ),

      // FaceTune separates surfaces with a hairline and a tint, not a shadow.
      // The one exception is a genuinely floating surface — a FAB or a menu —
      // where elevation communicates that it is above the page rather than part
      // of it.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: AppElevation.floating,
        backgroundColor: AppColors.rose,
        foregroundColor: Colors.white,
        extendedTextStyle: text.labelLarge,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          backgroundColor: AppColors.rose,
          foregroundColor: Colors.white,
          disabledBackgroundColor: isDark ? Colors.white10 : AppColors.sand,
          disabledForegroundColor: isDark
              ? AppColors.taupeLight
              : AppColors.taupe,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: text.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 56),
          foregroundColor: isDark ? Colors.white : AppColors.cocoa,
          disabledForegroundColor: isDark
              ? AppColors.taupeLight
              : AppColors.taupe,
          side: BorderSide(color: outline, width: AppBorders.hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: text.labelLarge,
        ),
      ),

      // The tertiary rung. It exists so a screen that needs a low-emphasis
      // action reaches for a themed variant instead of a bare `TextButton` with
      // whatever default the framework supplies.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: isDark ? AppColors.roseLight : AppColors.rose,
          disabledForegroundColor: isDark
              ? AppColors.taupeLight
              : AppColors.taupe,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          textStyle: text.labelLarge,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkCard : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md + 2,
          vertical: AppSpacing.md + 1,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: hairline, width: AppBorders.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(
            color: AppColors.rose,
            width: AppBorders.emphasis,
          ),
        ),
        // Previously absent entirely, so a failed validation fell back to
        // Material's default red rather than the brand's, and the invalid state
        // was the only one with no defined appearance.
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: errorText, width: AppBorders.hairline),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: errorText, width: AppBorders.emphasis),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: hairline, width: AppBorders.hairline),
        ),
        errorStyle: text.bodySmall?.copyWith(color: errorText),
        helperStyle: text.bodySmall?.copyWith(
          color: isDark ? AppColors.taupeLight : AppColors.taupe,
        ),
        hintStyle: text.bodyMedium?.copyWith(
          color: isDark ? AppColors.taupeLight : AppColors.taupe,
        ),
        prefixIconColor: isDark ? AppColors.taupeLight : AppColors.taupe,
        suffixIconColor: isDark ? AppColors.taupeLight : AppColors.taupe,
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: AppElevation.none,
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        indicatorColor: isDark ? AppColors.roseDark : AppColors.blush,
        labelTextStyle: WidgetStatePropertyAll(text.labelSmall),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        titleTextStyle: text.titleLarge?.copyWith(
          color: isDark ? Colors.white : AppColors.cocoa,
        ),
        contentTextStyle: text.bodyMedium?.copyWith(
          color: isDark ? Colors.white70 : AppColors.cocoa,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
        ),
      ),

      // Transient feedback. Themed rather than left to Material because 24 of
      // the app's 29 snackbars pass no colour at all — so this is what almost
      // every message the user gets actually looks like.
      //
      // Behaviour is deliberately left at Material's default (fixed, bottom).
      // `floating` reads more modern but overlaps the navigation bar and
      // narrows the content box, and that trade cannot be judged without a
      // device.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: semantics.info.feedbackSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: semantics.info.onFeedbackSurface,
        ),
        actionTextColor: semantics.info.onFeedbackSurface,
        // White-on-tone at every tone clears 5:1, so the action is set apart by
        // weight rather than by a second colour that would have to be
        // re-verified against four different grounds.
        actionBackgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),

      // Previously unthemed, so every `Divider(height: 1)` in the app drew
      // Material's default grey rather than the brand hairline.
      dividerTheme: DividerThemeData(
        color: hairline,
        thickness: AppBorders.hairline,
        space: AppSpacing.md,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        selectedColor: isDark ? AppColors.roseDark : AppColors.blush,
        labelStyle: text.labelMedium,
        side: BorderSide(color: hairline, width: AppBorders.hairline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: isDark ? AppColors.roseLight : AppColors.rose,
        titleTextStyle: text.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppColors.cocoa,
        ),
        subtitleTextStyle: text.bodySmall?.copyWith(
          color: isDark ? AppColors.taupeLight : AppColors.taupe,
        ),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: isDark
              ? AppColors.roseDark
              : AppColors.blush,
          selectedForegroundColor: isDark ? Colors.white : AppColors.cocoa,
          foregroundColor: isDark ? AppColors.taupeLight : AppColors.taupe,
          side: BorderSide(color: outline, width: AppBorders.hairline),
          textStyle: text.labelMedium,
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        strokeWidth: 2.5,
        strokeCap: StrokeCap.round,
      ),

      // The icon policy's anchor. FaceTune uses the Material family only, at the
      // sizes in AppIconSizes, and never emoji: an emoji is a font-dependent
      // colour glyph that ignores the theme, cannot be recoloured for contrast,
      // and is read aloud by a screen reader as its CLDR name.
      iconTheme: IconThemeData(
        size: AppIconSizes.md,
        color: isDark ? Colors.white70 : AppColors.cocoa,
      ),

      // Motion. FaceTune's page changes fade forward rather than slide, which
      // is Material 3's current guidance and reads calmer than the platform
      // zoom — the right register for a product whose direction is "calm,
      // editorial, restrained".
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
