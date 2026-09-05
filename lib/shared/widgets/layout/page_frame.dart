import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';

/// The readable column every screen sits in.
///
/// Two jobs. It caps line length on wide screens, because a paragraph running
/// the full width of a tablet is unreadable however well it is styled. And it
/// fixes the horizontal inset from the screen edge at one value app-wide, which
/// is most of what makes a set of screens feel like one product.
///
/// [maxWidth] is why a screen cannot rely on being wider than 720 — a layout
/// branch keyed above that width will never run inside a default `PageFrame`.
class PageFrame extends StatelessWidget {
  const PageFrame({
    required this.child,
    super.key,
    this.maxWidth = defaultMaxWidth,
    this.padding = defaultPadding,
  });

  /// A frame whose child is a scroll view.
  ///
  /// Same gutter and same lead-in; no bottom tail. Padding wrapped around a
  /// scroll view sits *outside* its viewport, so a tail here is not clearance
  /// at the end of a scroll — it is dead ground at every offset, and on a
  /// screen inside `AppShell` it draws as an empty band above the navigation
  /// bar that the content can never scroll into.
  ///
  /// The clearance it was added for is already there: `Scaffold` lays its body
  /// out *above* `bottomNavigationBar`, so the last item clears the bar without
  /// help. A scrolling screen supplies its own trailing gap as a final sliver
  /// instead, where it scrolls with the content it belongs to.
  const PageFrame.scrolling({
    required this.child,
    super.key,
    this.maxWidth = defaultMaxWidth,
  }) : padding = scrollingPadding;

  /// The readable column width a screen gets unless it asks for another.
  ///
  /// Named rather than left as a literal default so a component drawn *outside*
  /// the frame — a bottom bar in `Scaffold.bottomNavigationBar`, which is not a
  /// descendant of the body's `PageFrame` — can line its content up with the
  /// column above it instead of guessing the same number again.
  static const double defaultMaxWidth = 720;

  /// Gutter on both sides; a small lead-in at the top because a screen's first
  /// element usually follows an app bar; a generous tail at the bottom so the
  /// last element is not left sitting on the edge of the screen.
  ///
  /// For a scrolling child use [PageFrame.scrolling] instead — this tail cannot
  /// scroll, and on a screen with a bottom navigation bar it reads as a band.
  static const EdgeInsets defaultPadding = EdgeInsets.fromLTRB(
    AppSpacing.gutter,
    AppSpacing.xs,
    AppSpacing.gutter,
    AppSpacing.xl,
  );

  /// The padding [PageFrame.scrolling] applies. Public so a test can assert the
  /// bottom tail is gone rather than re-measuring a rendered screen to find it.
  static const EdgeInsets scrollingPadding = EdgeInsets.fromLTRB(
    AppSpacing.gutter,
    AppSpacing.xs,
    AppSpacing.gutter,
    0,
  );

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(padding: padding, child: child),
    ),
  );
}
