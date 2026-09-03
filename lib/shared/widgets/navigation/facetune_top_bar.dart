import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import 'facetune_back_button.dart';
import 'facetune_nav_metrics.dart';

/// The top bar every route-level screen shares.
///
/// A thin arrangement over `AppBar`, not a replacement for it. That is the
/// whole point: the app bar theme, the status-bar overlay style, the transparent
/// ground and the scroll-under behaviour are already decided once in
/// `AppTheme`, and a hand-rolled row would have quietly forked all four. What
/// this adds is the parts a screen kept re-deciding — which control draws the
/// back affordance, how far it sits from the edge, and where a title and a
/// trailing action line up against it.
///
/// Three configurations, and a screen picks by what it passes:
///
///  * **Back only** — `FaceTuneTopBar()`, for a page whose own content already
///    says where the user is. The result page is the case that motivated it.
///  * **Back and title** — `FaceTuneTopBar(title: 'My Makeup Kit')`.
///  * **Back, title and trailing actions** — add `actions`.
///
/// Whether the back control appears is decided the same way `AppBar` decides
/// it, from the route's own `impliesAppBarDismissal`. A screen reached with
/// `go` therefore shows no back control here, exactly as it shows none today.
class FaceTuneTopBar extends StatelessWidget implements PreferredSizeWidget {
  const FaceTuneTopBar({
    super.key,
    this.title,
    this.actions,
    this.onBack,
    this.showBack,
  });

  /// Omit where the page's first line of content is the better title.
  final String? title;

  /// Trailing utility actions. Standard 48-wide `IconButton`s line up with the
  /// gutter without further padding.
  final List<Widget>? actions;

  /// Where back goes. Omit to keep the route's existing pop behaviour.
  final VoidCallback? onBack;

  /// Forces the back control on or off. Omit to mirror `AppBar`'s own rule,
  /// which is what preserves current behaviour screen by screen.
  final bool? showBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final showsBack =
        showBack ?? (ModalRoute.of(context)?.impliesAppBarDismissal ?? false);
    return AppBar(
      // The leading slot is ours, so the framework must not also fill it.
      automaticallyImplyLeading: false,
      leadingWidth: FaceTuneNavMetrics.leadingWidth,
      leading: showsBack
          ? Padding(
              padding: const EdgeInsets.only(left: AppSpacing.gutter),
              child: Center(child: FaceTuneBackButton(onPressed: onBack)),
            )
          : null,
      // With a back control the title follows it by one small step; without
      // one the title starts on the page gutter, so a titled screen with no
      // back looks like the same product as one with it.
      titleSpacing: showsBack
          ? FaceTuneNavMetrics.titleSpacing
          : AppSpacing.gutter,
      title: title == null
          ? null
          : Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: actions == null
          ? null
          : <Widget>[
              ...actions!,
              const SizedBox(width: FaceTuneNavMetrics.trailingInset),
            ],
    );
  }
}
