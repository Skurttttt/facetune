import 'package:flutter/material.dart';

import '../../../theme/app_semantics.dart';
import '../../../theme/app_tokens.dart';

/// An inline block that tells the user something about their situation.
///
/// This replaces a pattern the UI-P0 audit found repeated **22 times across 15
/// files**, hand-assembled each time as `AppCard(color: AppColors.petal)` plus
/// an icon plus a `Row`. Duplication was the smaller problem. The real one was
/// that the pink tint was the *only* tint available, so it ended up carrying
/// contradictory meanings on one screen: `scan_page.dart` rendered "Local checks
/// passed" and "Analysis paused" on the identical surface. A user could not tell
/// success from failure by looking.
///
/// [tone] fixes that. It selects a surface, a border, a foreground and a default
/// icon together, from [AppSemantics], so the four can never be mixed into an
/// illegible combination.
///
/// Meaning is never carried by colour alone — every notice has an icon and
/// words. That is what makes the distinction survive both a colour-blind reader
/// and a greyscale screenshot.
class AppNotice extends StatelessWidget {
  const AppNotice({
    required this.message,
    super.key,
    this.tone = AppTone.info,
    this.title,
    this.icon,
    this.actions = const [],
    this.liveRegion = false,
  });

  /// The body copy. Required — a notice with no words is a coloured rectangle.
  final String message;

  /// What this notice means. Drives surface, border, foreground and icon.
  final AppTone tone;

  /// Optional emphasis line above [message].
  final String? title;

  /// Overrides [AppTone.icon] where a more specific glyph is clearer — a cloud
  /// for an offline failure, say. Must not contradict [tone].
  final IconData? icon;

  /// Recovery or follow-up actions. Wrapped, so they stack on a narrow screen
  /// rather than overflowing.
  final List<Widget> actions;

  /// Announce this notice when it appears.
  ///
  /// Off by default: a notice that is simply part of the page should not
  /// interrupt a screen reader. Turn it on when the notice is the *result* of
  /// something the user just did — a failed validation, an expired session —
  /// where silence would leave them waiting for feedback that never comes.
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final role = tone.resolve(context);
    final theme = Theme.of(context);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: theme.textTheme.titleSmall?.copyWith(color: role.onSurface),
          ),
          const SizedBox(height: AppSpacing.xxs),
        ],
        Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(color: role.onSurface),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            children: actions,
          ),
        ],
      ],
    );

    return Semantics(
      container: true,
      liveRegion: liveRegion,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: role.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: role.border, width: AppBorders.hairline),
        ),
        // The role's foreground is pushed down through the text and icon themes
        // as well as being set explicitly above. Belt and braces on purpose: a
        // child that passes its own `Theme.of(context).textTheme.*` style would
        // otherwise keep the theme's near-white `onSurface` and vanish against
        // the pale surface in dark mode — the exact failure `AppCard` already
        // guards against.
        child: Theme(
          data: theme.copyWith(
            textTheme: theme.textTheme.apply(
              bodyColor: role.onSurface,
              displayColor: role.onSurface,
            ),
            iconTheme: theme.iconTheme.copyWith(color: role.accent),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: role.onSurface),
            child: _layout(context, role, body),
          ),
        ),
      ),
    );
  }

  /// Icon beside the text, or above it once the text is large.
  ///
  /// At a 2x text scale a 24pt icon and a wrapped paragraph in one `Row` leaves
  /// the text a column too narrow to read. Stacking recovers the full width.
  Widget _layout(BuildContext context, AppSemanticRole role, Widget body) {
    final glyph = Icon(
      icon ?? tone.icon,
      color: role.accent,
      size: AppIconSizes.md,
    );
    final scaled = MediaQuery.textScalerOf(context).scale(14);

    if (scaled > 22) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          glyph,
          const SizedBox(height: AppSpacing.xs),
          body,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        glyph,
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: body),
      ],
    );
  }
}
