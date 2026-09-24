import 'package:flutter/material.dart';

import 'admin_tokens.dart';

/// Web Admin typography (WA-13.5-UI-1), from the UI SOT section 9.
///
/// Dense administrative data, not a consumer beauty app: hierarchy comes from
/// weight and colour rather than from large type. No condensed display face.
///
/// Weight note: the SOT specifies 650 and 550 for some roles. Flutter's
/// [FontWeight] is quantised to hundreds and this project bundles no variable
/// font, so 650 renders as [FontWeight.w600] and 550 as [FontWeight.w500].
/// The intended hierarchy is preserved; only the exact stem weight differs.
abstract final class AdminTypography {
  /// Preferred stack. Nothing is bundled and no font package is added, so
  /// these resolve through the browser's own font stack and fall back to the
  /// platform sans-serif.
  static const fontFamily = 'Inter';
  static const fontFamilyFallback = <String>['Roboto'];

  static const _semiBold = FontWeight.w600; // SOT 650 / 600
  static const _medium = FontWeight.w500; // SOT 550
  static const _regular = FontWeight.w400;

  /// 24 / 32, 650. One per page.
  static const pageTitle = TextStyle(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: _semiBold,
    color: AdminColors.textPrimary,
  );

  /// 14 / 21, 400. The sentence under a page title.
  static const pageSubtitle = TextStyle(
    fontSize: 14,
    height: 21 / 14,
    fontWeight: _regular,
    color: AdminColors.textSecondary,
  );

  /// 18 / 26, 600.
  static const sectionTitle = TextStyle(
    fontSize: 18,
    height: 26 / 18,
    fontWeight: _semiBold,
    color: AdminColors.textPrimary,
  );

  /// 13 / 18, 550.
  static const cardTitle = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: _medium,
    color: AdminColors.textSecondary,
  );

  /// 28, 650. The number on a statistic tile.
  static const metricValue = TextStyle(
    fontSize: 28,
    height: 34 / 28,
    fontWeight: _semiBold,
    color: AdminColors.textPrimary,
  );

  /// 13, 600.
  static const tableHeading = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: _semiBold,
    color: AdminColors.textSecondary,
  );

  /// 14 / 20, 400.
  static const tableContent = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: _regular,
    color: AdminColors.textPrimary,
  );

  /// 13, 550.
  static const formLabel = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: _medium,
    color: AdminColors.textPrimary,
  );

  /// 12 / 18, 400.
  static const helperText = TextStyle(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: _regular,
    color: AdminColors.textSecondary,
  );

  /// 14, 600.
  static const button = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: _semiBold,
  );

  /// 14, 550.
  static const navigation = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: _medium,
    color: AdminColors.textPrimary,
  );

  /// 12, 400.
  static const metadata = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: _regular,
    color: AdminColors.textSecondary,
  );

  /// 12, 600.
  static const statusBadge = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: _semiBold,
  );

  /// The Material [TextTheme] the console's roles map onto.
  ///
  /// Material's slots are a delivery mechanism; the named roles above are the
  /// authority. This mapping is deliberately *transitional*: it is chosen so
  /// that the six slots the admin actually uses today keep the size they
  /// already render at, so UI-1 changes colour and weight without moving
  /// layout. UI-4 and UI-6 replace these slot lookups with explicit
  /// `PageHeader`, `StatCard` and `AdminTable` components that read the named
  /// roles directly.
  ///
  /// Slots in use today and what they carry:
  ///
  /// * `headlineMedium` (3) - statistic tile values, so it maps to
  ///   [metricValue]; Material's own default is also 28.
  /// * `headlineSmall` (7) - page titles, so it maps to [pageTitle]; Material's
  ///   own default is also 24.
  /// * `titleMedium` (13) - section and group headings, so it maps to
  ///   [sectionTitle]. This is the one intentional size change in UI-1: 16 to
  ///   18, because the SOT defines no 16px role and inventing one would put a
  ///   value outside the design system into the theme.
  /// * `bodyMedium` (15) - table and body content, 14 either way.
  /// * `bodySmall` (17) - helper and caption text, 12 either way.
  /// * `labelMedium` (10) - tile and detail-row labels, which is the card
  ///   title role, 12 to 13.
  static const textTheme = TextTheme(
    displaySmall: metricValue,
    headlineLarge: metricValue,
    headlineMedium: metricValue,
    headlineSmall: pageTitle,
    titleLarge: sectionTitle,
    titleMedium: sectionTitle,
    titleSmall: formLabel,
    bodyLarge: tableContent,
    bodyMedium: tableContent,
    bodySmall: helperText,
    labelLarge: button,
    labelMedium: cardTitle,
    labelSmall: metadata,
  );
}
