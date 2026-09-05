import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';

/// Geometry shared by the four top-level screens' headers.
///
/// Component constants rather than entries in `app_tokens.dart`, for the same
/// reason [FaceTuneNavMetrics] is: these are the dimensions of one component
/// family, not a scale anything else should be reading. What matters is that
/// they live in exactly one place — before this, Home, Saved, History and
/// Profile each decided their own, and the four disagreed.
abstract final class TopLevelHeaderMetrics {
  /// Breathing room between the safe area and the page title.
  ///
  /// The four headers had none: `PageFrame`'s 8pt lead-in was the entire gap
  /// between the status bar and a 27pt headline, which is what made every
  /// top-level screen look like it started too high. The lead-in is a lead-in,
  /// not breathing room, so the header supplies its own rather than the frame
  /// growing a top inset that every non-header screen would also pay.
  static const topInset = AppSpacing.lg;

  /// Title to subtitle. Small on purpose: the two are one unit, and a larger
  /// gap here reads as two separate things rather than a heading and its line.
  static const titleGap = AppSpacing.xs;

  /// Header to the first major content below it.
  ///
  /// Public so the pages can space their own first section by the same value
  /// without guessing it again — the header cannot own this gap itself, because
  /// Saved and History put a guest notice between the subtitle and their first
  /// section.
  static const contentGap = AppSpacing.lg;
}

/// The header Saved, History and Profile share.
///
/// Title, an optional supporting line, and an optional trailing action that
/// belongs to the *title row* — not floated over the page. Profile's settings
/// button is the case that motivated it: aligning a trailing control by hand is
/// how a screen ends up with a magic offset that only looks right on one phone.
///
/// The subtitle is drawn in the muted role every other piece of supporting copy
/// in the app uses. Saved and History previously left theirs at full contrast,
/// so their subtitles competed with their titles while Home's did not.
class TopLevelPageHeader extends StatelessWidget {
  const TopLevelPageHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
  });

  final String title;

  /// Omit where the page's first section already says what the screen is for.
  final String? subtitle;

  /// A single utility action. Sits on the title's baseline row, so it stays put
  /// as the title wraps or the subtitle grows.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle;
    return Padding(
      padding: const EdgeInsets.only(top: TopLevelHeaderMetrics.topInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              ?trailing,
            ],
          ),
          if (subtitleText != null) ...[
            const SizedBox(height: TopLevelHeaderMetrics.titleGap),
            Text(
              subtitleText,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted(context)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Home's companion to [TopLevelPageHeader].
///
/// Same safe-area strategy, same top inset, same gutter (both sit inside the
/// page's `PageFrame`), same title-to-supporting-line gap, and the same rule
/// that the trailing control belongs to the title row.
///
/// What it deliberately does *not* share is the title size. Home is a dashboard
/// greeting rather than a page title: it names the reader, not the screen, and
/// at `headlineMedium` it would announce itself more loudly than the scan hero
/// directly beneath it. The hierarchy is the point of the separate component —
/// a `titleStyle` parameter on the shared header would have been an invitation
/// for the other three to drift too.
class HomeGreetingHeader extends StatelessWidget {
  const HomeGreetingHeader({
    required this.greeting,
    super.key,
    this.supportingText,
    this.trailing,
  });

  /// Carries a display name, so it is allowed to wrap. Truncating what someone
  /// chose to be called is worse than giving it a second line.
  final String greeting;

  final String? supportingText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final supporting = supportingText;
    return Padding(
      padding: const EdgeInsets.only(top: TopLevelHeaderMetrics.topInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  greeting,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              ?trailing,
            ],
          ),
          if (supporting != null) ...[
            const SizedBox(height: TopLevelHeaderMetrics.titleGap),
            Text(
              supporting,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted(context)),
            ),
          ],
        ],
      ),
    );
  }
}
