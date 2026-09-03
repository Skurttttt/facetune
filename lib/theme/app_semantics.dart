import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// One semantic outcome's complete surface treatment.
///
/// Four fields rather than one colour because a notice needs all four to be
/// legible and to be *distinguishable*: measured against the page ground, the
/// tinted surfaces separate by only 1.05–1.10:1 in dark mode, so the surface
/// alone does not delineate the block. The [border] does that; the [accent]
/// and the icon it colours carry the meaning.
///
/// That split matters beyond tidiness. Colour is never the only signal — every
/// notice also carries an icon and words — so the role reads correctly for a
/// colour-blind user, who is precisely the person a pink-means-both-outcomes
/// design fails hardest.
@immutable
class AppSemanticRole {
  const AppSemanticRole({
    required this.surface,
    required this.onSurface,
    required this.accent,
    required this.border,
    required this.feedbackSurface,
    required this.onFeedbackSurface,
  });

  /// The tinted block behind the notice.
  final Color surface;

  /// Body copy drawn on [surface]. Clears 4.5:1 in both themes.
  final Color onSurface;

  /// The icon, and any emphasised label, drawn on [surface]. Clears 4.5:1 in
  /// both themes — the text minimum, not merely the 3:1 graphics minimum, so
  /// the same value is safe whether it paints a glyph or a word.
  final Color accent;

  /// The hairline that separates [surface] from whatever it sits on.
  final Color border;

  /// A solid, high-emphasis ground for transient feedback — a snackbar.
  ///
  /// Deliberately *not* [surface]. A notice is part of the page and whispers;
  /// a snackbar is a temporary overlay that has to be noticed within a couple
  /// of seconds and then leave, so it inverts against the page instead of
  /// tinting with it.
  ///
  /// That inversion flips between themes, which is why this cannot be derived
  /// from [surface]: the light theme wants a dark ground, and in the dark theme
  /// a dark ground separates from the page by only 1.18:1 — a snackbar you
  /// cannot see is not feedback. The dark theme therefore uses a *light* ground
  /// with dark text.
  final Color feedbackSurface;

  /// The label drawn on [feedbackSurface]. Clears 5:1 in both themes.
  final Color onFeedbackSurface;

  AppSemanticRole lerpTo(AppSemanticRole other, double t) => AppSemanticRole(
    surface: Color.lerp(surface, other.surface, t)!,
    onSurface: Color.lerp(onSurface, other.onSurface, t)!,
    accent: Color.lerp(accent, other.accent, t)!,
    border: Color.lerp(border, other.border, t)!,
    feedbackSurface: Color.lerp(feedbackSurface, other.feedbackSurface, t)!,
    onFeedbackSurface: Color.lerp(
      onFeedbackSurface,
      other.onFeedbackSurface,
      t,
    )!,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSemanticRole &&
          surface == other.surface &&
          onSurface == other.onSurface &&
          accent == other.accent &&
          border == other.border &&
          feedbackSurface == other.feedbackSurface &&
          onFeedbackSurface == other.onFeedbackSurface;

  @override
  int get hashCode => Object.hash(
    surface,
    onSurface,
    accent,
    border,
    feedbackSurface,
    onFeedbackSurface,
  );
}

/// The meanings a surface can carry, resolved for the active theme.
///
/// Read it with `AppSemantics.of(context)`.
///
/// This exists because FaceTune had no semantic layer at all: `AppColors.petal`
/// was doing duty as the info surface, the success surface *and* the error
/// surface — on the scan screen, "your photo passed" and "analysis failed" were
/// rendered on the identical pink card. `AppColors.error` was defined but never
/// reached a single inline surface. A user could not tell the two outcomes apart
/// by looking.
///
/// A `ThemeExtension` rather than a set of `static Color foo(BuildContext)`
/// helpers, for three reasons: it resolves once per theme instead of on every
/// call, it lerps correctly while the theme animates between light and dark, and
/// it is the mechanism Material 3 documents for exactly this, so the next person
/// finds it where they expect it.
@immutable
class AppSemantics extends ThemeExtension<AppSemantics> {
  const AppSemantics({
    required this.info,
    required this.success,
    required this.warning,
    required this.danger,
  });

  /// Neutral context. Guidance, explanations, "here is how this works".
  final AppSemanticRole info;

  /// A thing the user did worked, or a precondition is satisfied.
  final AppSemanticRole success;

  /// Not an error, but proceed knowing something. Temporary accounts,
  /// irreversible actions, incomplete input.
  final AppSemanticRole warning;

  /// Something failed, or is blocked. This is the one that must never again be
  /// indistinguishable from [success].
  final AppSemanticRole danger;

  /// Every ratio below is asserted in `test/theme/design_system_test.dart`.
  /// Editing a value here without running that test is how AA quietly breaks.
  /// Light theme: pale tinted notices, and dark solid snackbars.
  static const light = AppSemantics(
    info: AppSemanticRole(
      surface: AppColors.petal, // #FBEFF2
      onSurface: AppColors.cocoa, // 13.66:1
      accent: AppColors.rose, // 4.70:1
      border: Color(0xFFE6C6D1),
      // Neutral rather than rose: most feedback is not about a brand moment,
      // and a pink snackbar for "Saved" reads as decoration, not confirmation.
      feedbackSurface: AppColors.cocoa,
      onFeedbackSurface: Colors.white, // 15.31:1
    ),
    success: AppSemanticRole(
      surface: Color(0xFFEDF3F0),
      onSurface: AppColors.cocoa, // 13.62:1
      accent: AppColors.successDeep, // 5.51:1
      border: Color(0xFFBFD5CA),
      feedbackSurface: AppColors.successDeep,
      onFeedbackSurface: Colors.white, // 6.20:1
    ),
    warning: AppSemanticRole(
      surface: Color(0xFFFAF3E8),
      onSurface: AppColors.cocoa, // 13.89:1
      accent: AppColors.goldDeep, // 4.73:1  (plain `gold` is 2.83:1 here)
      border: Color(0xFFE4CEA6),
      // goldDeep again: plain `gold` under white text is 3.12:1, another fail.
      feedbackSurface: AppColors.goldDeep,
      onFeedbackSurface: Colors.white, // 5.21:1
    ),
    danger: AppSemanticRole(
      surface: Color(0xFFFCEDEE),
      onSurface: AppColors.cocoa, // 13.48:1
      accent: AppColors.errorDeep, // 5.72:1
      border: Color(0xFFEFC5C9),
      feedbackSurface: AppColors.errorDeep,
      onFeedbackSurface: Colors.white, // 6.50:1
    ),
  );

  /// Dark theme: dark tinted notices, and *light* solid snackbars.
  ///
  /// The snackbar inversion is the part that is easy to get wrong. Reusing the
  /// light theme's dark grounds here would put a #2E2225 bar on a #1A1517 page
  /// — 1.18:1, effectively invisible.
  static const dark = AppSemantics(
    info: AppSemanticRole(
      surface: Color(0xFF33242B),
      onSurface: Color(0xFFF3E9EC), // 12.38:1
      accent: AppColors.roseLight, // 5.88:1
      border: Color(0xFF4A333C),
      feedbackSurface: AppColors.blush,
      onFeedbackSurface: AppColors.cocoa, // 11.91:1
    ),
    success: AppSemanticRole(
      surface: Color(0xFF202B26),
      onSurface: Color(0xFFE9F1ED), // 12.73:1
      accent: AppColors.successLight, // 6.85:1
      border: Color(0xFF2F4038),
      feedbackSurface: AppColors.successLight,
      onFeedbackSurface: AppColors.cocoa, // 7.16:1
    ),
    warning: AppSemanticRole(
      surface: Color(0xFF2E2618),
      onSurface: Color(0xFFF3EDE2), // 12.81:1
      accent: AppColors.goldLight, // 7.64:1
      border: Color(0xFF443722),
      feedbackSurface: AppColors.goldLight,
      onFeedbackSurface: AppColors.cocoa, // 7.84:1
    ),
    danger: AppSemanticRole(
      surface: Color(0xFF331F23),
      onSurface: Color(0xFFF7EAEC), // 13.18:1
      accent: AppColors.errorLight, // 6.53:1
      border: Color(0xFF4A2C31),
      feedbackSurface: AppColors.errorLight,
      onFeedbackSurface: AppColors.cocoa, // 6.48:1
    ),
  );

  /// The roles for the active theme.
  ///
  /// Falls back to [light] only if the extension is somehow unregistered, which
  /// cannot happen through [AppTheme] but can in a bare `MaterialApp` inside a
  /// test. Returning a working set beats throwing in a widget build.
  static AppSemantics of(BuildContext context) =>
      Theme.of(context).extension<AppSemantics>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  AppSemantics copyWith({
    AppSemanticRole? info,
    AppSemanticRole? success,
    AppSemanticRole? warning,
    AppSemanticRole? danger,
  }) => AppSemantics(
    info: info ?? this.info,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
  );

  @override
  AppSemantics lerp(ThemeExtension<AppSemantics>? other, double t) {
    if (other is! AppSemantics) return this;
    return AppSemantics(
      info: info.lerpTo(other.info, t),
      success: success.lerpTo(other.success, t),
      warning: warning.lerpTo(other.warning, t),
      danger: danger.lerpTo(other.danger, t),
    );
  }
}

/// Which meaning a surface carries.
///
/// Named [AppTone] rather than `AppSemanticType` because it appears at call
/// sites — `AppNotice(tone: AppTone.danger, …)` — and a long name there buries
/// the thing that matters.
enum AppTone {
  info,
  success,
  warning,
  danger;

  /// This tone's resolved treatment for the active theme.
  AppSemanticRole resolve(BuildContext context) {
    final semantics = AppSemantics.of(context);
    return switch (this) {
      AppTone.info => semantics.info,
      AppTone.success => semantics.success,
      AppTone.warning => semantics.warning,
      AppTone.danger => semantics.danger,
    };
  }

  /// The default icon for this tone.
  ///
  /// A default rather than a fixed mapping: a caller with a more specific glyph
  /// (a cloud for an offline failure) should pass it. What a caller must not do
  /// is pass an icon that contradicts the tone, which is why the fallback is
  /// unambiguous rather than decorative.
  IconData get icon => switch (this) {
    AppTone.info => Icons.info_outline_rounded,
    AppTone.success => Icons.check_circle_outline_rounded,
    AppTone.warning => Icons.warning_amber_rounded,
    AppTone.danger => Icons.error_outline_rounded,
  };
}
