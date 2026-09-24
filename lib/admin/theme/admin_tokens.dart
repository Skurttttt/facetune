import 'package:flutter/painting.dart';

/// Web Admin visual tokens (WA-13.5-UI-1).
///
/// These are the Web Admin's own values. They deliberately do NOT reuse
/// `lib/theme/app_tokens.dart`: that file is imported by 78 consumer Dart
/// files, so changing a value there to suit an operations console would move
/// the mobile app's layout. Nothing under `lib/admin/` may import the
/// consumer theme, and `admin_theme_test.dart` asserts that.
///
/// The canonical source for every number here is
/// `FACETUNE_WEB_ADMIN_UI_REDESIGN_SOURCE_OF_TRUTH.md` sections 8-10.

/// The Operational Dark SaaS palette (UI SOT section 8).
///
/// Semantic state is never communicated by colour alone; every status surface
/// pairs one of these with text. The accent is an action/selection colour, not
/// a universal status colour.
abstract final class AdminColors {
  /// Main application canvas.
  static const pageBackground = Color(0xFF0E1116);

  /// Persistent navigation.
  static const sidebarBackground = Color(0xFF101318);

  /// Cards, tables, filter panels, detail sections.
  static const surface = Color(0xFF151920);

  /// Inputs, hover surfaces, secondary containers.
  static const surfaceSecondary = Color(0xFF1B2028);

  /// Default 1px structural border.
  static const border = Color(0xFF2B313B);

  /// Focused / selected control border.
  static const borderStrong = Color(0xFF3A424E);

  /// Main readable content.
  static const textPrimary = Color(0xFFF4F5F7);

  /// Descriptions and metadata.
  static const textSecondary = Color(0xFFAAB2BD);

  /// Disabled / non-interactive content.
  static const textDisabled = Color(0xFF69727F);

  /// Primary action, selected navigation, links.
  static const accent = Color(0xFFC96386);

  /// Accent hover state.
  static const accentHover = Color(0xFFD97194);

  /// Selected navigation background / subtle selected state.
  static const accentSubtle = Color.fromRGBO(201, 99, 134, 0.14);

  /// Positive state.
  static const success = Color(0xFF49B97A);

  /// Warning state.
  static const warning = Color(0xFFE5A84B);

  /// Errors and destructive actions. Deliberately distinct from [accent]:
  /// revoking an entitlement must never look like a primary action.
  static const error = Color(0xFFE46770);

  /// Informational state.
  static const information = Color(0xFF5E92E8);

  /// Text drawn on top of [accent] or [error] fills.
  static const onAccent = Color(0xFF16090E);
}

/// The Web Admin spacing scale (UI SOT section 10): 4 / 8 / 12 / 16 / 20 / 24
/// / 32 / 40 / 48.
///
/// The names map 1:1 onto the values the admin already used from the consumer
/// scale (4, 8, 12, 16, 24, 32), so adopting these tokens moves nothing on
/// screen. [ml], [xxl] and [xxxl] are the steps the console needs and the
/// consumer scale does not have.
abstract final class AdminSpacing {
  /// Icon/text micro spacing.
  static const xxs = 4.0;

  /// Compact internal gap.
  static const xs = 8.0;

  /// Field/content micro grouping.
  static const sm = 12.0;

  /// Standard component padding.
  static const md = 16.0;

  /// Filter/control grouping.
  static const ml = 20.0;

  /// Card padding and small section gap.
  static const lg = 24.0;

  /// Standard section gap.
  static const xl = 32.0;

  /// Major page region separation.
  static const xxl = 40.0;

  /// Rare top-level separation.
  static const xxxl = 48.0;
}

/// Corner radii (UI SOT section 10). Buttons use control radius, never a
/// capsule; only semantic badges may be pills.
abstract final class AdminRadii {
  /// Buttons, inputs, dropdowns, date fields.
  static const control = 6.0;

  /// Cards and tables.
  static const card = 8.0;

  /// Large sections.
  static const section = 10.0;

  /// Dialogs.
  static const dialog = 10.0;

  /// Semantic badges only.
  static const pill = 999.0;
}

/// Structural borders. The console prefers borders over decorative shadows.
abstract final class AdminBorders {
  /// Default 1px structural border.
  static const hairline = 1.0;

  /// Focused / selected border.
  static const strong = 1.5;
}

/// Elevation (UI SOT section 10): none for most cards and tables, subtle for
/// dropdowns and popovers, modal elevation for dialogs only.
abstract final class AdminElevation {
  static const none = 0.0;
  static const popover = 4.0;
  static const dialog = 12.0;
}

/// Focus ring (UI SOT section 24): 2px accent ring with a 2px outer offset.
abstract final class AdminFocus {
  static const ringWidth = 2.0;
  static const ringOffset = 2.0;
  static const ringColor = AdminColors.accent;
}

/// Icon sizes used across the console.
abstract final class AdminIconSizes {
  /// Inline with body text.
  static const sm = 16.0;

  /// Buttons and table actions.
  static const md = 18.0;

  /// Navigation.
  static const lg = 20.0;
}

/// Minimum interactive target (UI SOT section 24).
abstract final class AdminTargets {
  static const minimum = 40.0;
}
