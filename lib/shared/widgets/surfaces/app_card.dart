import 'package:flutter/material.dart';

import '../../../theme/app_semantics.dart';
import '../../../theme/app_tokens.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.onTap,
    this.emphasized = false,
    this.selected,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;

  /// Marks this card as the selected or recommended one among its peers.
  ///
  /// The boundary is drawn at [AppBorders.emphasis] in the theme's info accent
  /// — the same language the focused text field and the selected
  /// `MakeupStyleCard` already speak, resolved per brightness so it stays
  /// readable on the dark surface. Surface, radius, padding and elevation are
  /// untouched: FaceTune separates surfaces with a hairline and a tint, so a
  /// selected surface earns a heavier hairline, not a shadow.
  ///
  /// The card also reports `selected` to assistive technology, so the state
  /// does not live in a stroke alone. That flag is the floor, not the whole
  /// answer: where the state matters, pair it with a visible word or glyph —
  /// a "Current plan" chip, a check — because a half-point of border weight is
  /// a confirmation for someone who already knows, not an announcement.
  ///
  /// Off by default, and when off the card is built exactly as before: no
  /// existing consumer changes appearance by taking this parameter's default.
  final bool emphasized;

  /// What the card tells assistive technology about selection.
  ///
  /// Null — the default — follows [emphasized], which is right for the common
  /// case where the heavier border marks the thing the user chose. Pass
  /// `false` where a card is emphasized for a different reason (recommended,
  /// featured) and is *not* the selected one: emphasis is visual weight,
  /// selection is a fact, and a screen reader must only be told the fact.
  /// Pass `true` to report selection on a card that is not emphasized.
  ///
  /// The flag is emitted on a node of its own rather than merged upward, so a
  /// card inside a list never marks the list as selected.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(padding: padding, child: child);
    final background = color;
    if (background != null) {
      // A hardcoded accent colour keeps its own brightness in both themes, so
      // the foreground has to be derived from that colour instead of inherited
      // from the theme. Recolouring the text theme (rather than wrapping in a
      // DefaultTextStyle) also covers children that pass an explicit
      // `Theme.of(context).textTheme.*` style, which would otherwise keep the
      // theme's near-white colour in dark mode.
      final theme = Theme.of(context);
      final foreground = AppColors.onAccent(background);
      content = Theme(
        data: theme.copyWith(
          textTheme: theme.textTheme.apply(
            bodyColor: foreground,
            displayColor: foreground,
          ),
          iconTheme: theme.iconTheme.copyWith(color: foreground),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: foreground),
          child: content,
        ),
      );
    }
    final card = Card(
      color: background,
      clipBehavior: Clip.antiAlias,
      // Null hands the shape back to `cardTheme`, which is where the default
      // radius and hairline live — so the un-emphasized card is the theme's
      // card, exactly as it was before this parameter existed.
      shape: emphasized
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              side: BorderSide(
                color: AppTone.info.resolve(context).accent,
                width: AppBorders.emphasis,
              ),
            )
          : null,
      child: InkWell(onTap: onTap, child: content),
    );
    if (!(selected ?? emphasized)) return card;
    return Semantics(container: true, selected: true, child: card);
  }
}
