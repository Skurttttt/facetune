import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';

/// The result's secondary actions, at secondary weight.
///
/// These were four full-width buttons stacked under the look, which gave Save,
/// Favorite, Share, Regenerate and Return Home the same visual claim on the
/// user as each other — and very nearly the same claim as the one action the
/// screen actually exists to offer. A list of equal buttons is not a hierarchy;
/// it is the absence of one.
///
/// So: Save and Show me how are the screen's committing actions and live in the
/// reserved bottom action area; Home is a top-bar utility; and what is left
/// here is one compact row of three peers. Nothing about what any of them
/// *does* changed — every callback is the one that was passed here before.
///
/// Home used to sit at the bottom of this group as a quiet text action. It is
/// gone from here, not disabled: the same destination is now the top-right
/// utility, and two Home controls on one screen was one too many.
///
/// [onShare] is nullable because sharing is a capability one mode has and the
/// other does not. My Makeup Kit has no share service for its previews, so it
/// omits the control rather than showing one that would do nothing — a button
/// that lies is worse than a row of two.
class ResultActions extends StatelessWidget {
  const ResultActions({
    required this.isFavorite,
    required this.isSharing,
    required this.isMutating,
    required this.onFavorite,
    required this.onGenerateAnother,
    super.key,
    this.onShare,
  });

  final bool isFavorite;
  final bool isSharing;
  final bool isMutating;
  final VoidCallback onFavorite;
  final VoidCallback? onShare;
  final VoidCallback onGenerateAnother;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final actions = <_CompactAction>[
            _CompactAction(
              controlKey: const ValueKey('result-action-favorite'),
              icon: isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: isFavorite ? 'Favorited' : 'Favorite',
              // Says what the press will do, which the visual label often
              // cannot: "Favorited" describes the state it is already in.
              semanticsLabel: isFavorite ? 'Remove from favorites' : 'Favorite',
              onPressed: isMutating ? null : onFavorite,
            ),
            if (onShare != null)
              _CompactAction(
                controlKey: const ValueKey('result-action-share'),
                icon: Icons.share_outlined,
                label: isSharing ? 'Preparing' : 'Share',
                semanticsLabel: 'Share look',
                // The shared spinner, so this matches every other in-flight
                // control in the app instead of being a fourth hand-rolled one.
                isLoading: isSharing,
                onPressed: isSharing ? null : onShare,
              ),
            _CompactAction(
              controlKey: const ValueKey('result-action-try-another'),
              icon: Icons.refresh_rounded,
              label: 'Try another',
              semanticsLabel: 'Try another variation',
              onPressed: onGenerateAnother,
            ),
          ];

          // Three columns survive the primary target: the POCO's 393pt screen
          // leaves 353 inside the page gutter, so each action gets ~112 — wide
          // enough for "Try another" on two lines. Below that, or once large
          // text has grown the labels, they give up the row and become
          // full-width actions. A clipped label is worse than a taller screen.
          final stackActions =
              constraints.maxWidth < 320 ||
              MediaQuery.textScalerOf(context).scale(14) > 19;
          if (stackActions) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < actions.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: AppSpacing.xs),
                  actions[i].asRow(),
                ],
              ],
            );
          }
          // `IntrinsicHeight` so the three tiles share the tallest one's
          // height: "Try another" wraps to two lines where the others do not,
          // and three buttons of visibly different heights read as three
          // unrelated controls rather than one row of peers. The row sits in an
          // unbounded column, so stretching without it would ask for infinity.
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < actions.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: AppSpacing.xs),
                  Expanded(child: actions[i].asColumn()),
                ],
              ],
            ),
          );
        },
      ),
      // No caption under the row. "Try another" already says what it does, and
      // a sentence explaining a two-word button is the kind of copy that
      // accumulates until a screen reads like a manual.
    ],
  );
}

/// One utility action, in either of the two shapes the row can take.
///
/// A description rather than a widget, so the layout decision above picks a
/// shape without either branch having to restate the icon, the label, the
/// spoken label and the callback.
///
/// Both shapes are an [OutlinedButton] rather than a hand-built surface, so
/// they inherit the app's outlined geometry, border, disabled treatment and
/// pressed state instead of forking a fifth button style for one row. The
/// spoken label rides on the visible [Text] via `semanticsLabel`: the button
/// merges its descendants, so the node keeps its button role and its tap
/// action and only the words change.
class _CompactAction {
  const _CompactAction({
    required this.controlKey,
    required this.icon,
    required this.label,
    required this.semanticsLabel,
    required this.onPressed,
    this.isLoading = false,
  });

  final Key controlKey;
  final IconData icon;
  final String label;
  final String semanticsLabel;
  final VoidCallback? onPressed;
  final bool isLoading;

  Widget get _glyph => isLoading
      ? const ButtonProgress(size: AppIconSizes.sm)
      : Icon(icon, size: 20);

  /// The full-width form, used when three columns will not fit.
  Widget asRow() => OutlinedButton.icon(
    key: controlKey,
    onPressed: onPressed,
    icon: _glyph,
    label: Text(label, semanticsLabel: semanticsLabel),
  );

  Widget asColumn() => OutlinedButton(
    key: controlKey,
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.xxs,
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _glyph,
        const SizedBox(height: AppSpacing.xxs),
        // Wraps rather than truncates. A label the user cannot finish reading
        // is not a smaller button, it is a broken one.
        Text(
          label,
          textAlign: TextAlign.center,
          semanticsLabel: semanticsLabel,
        ),
      ],
    ),
  );
}
