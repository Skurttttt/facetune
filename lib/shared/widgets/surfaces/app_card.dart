import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;

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
    return Card(
      color: background,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
