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
    this.maxWidth = 720,
    this.padding = defaultPadding,
  });

  /// Gutter on both sides; a small lead-in at the top because a screen's first
  /// element usually follows an app bar; a generous tail at the bottom so the
  /// last element clears the navigation bar and the gesture area.
  static const EdgeInsets defaultPadding = EdgeInsets.fromLTRB(
    AppSpacing.gutter,
    AppSpacing.xs,
    AppSpacing.gutter,
    AppSpacing.xl,
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
