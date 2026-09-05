import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import 'history_card.dart';

/// A [HistoryCard] with nothing in it yet.
///
/// Its geometry is taken from the real card rather than approximated: the same
/// thumbnail box, the same padding, the same four stacked lines. That is the
/// whole point — when the records arrive, text replaces bars and nothing moves.
///
/// The shared [SkeletonCard] is not reused here because it draws a different
/// card: image on top, text beneath. Matching the wrong shape would reintroduce
/// exactly the layout shift this is meant to remove.
class HistoryCardSkeleton extends StatefulWidget {
  const HistoryCardSkeleton({super.key});

  @override
  State<HistoryCardSkeleton> createState() => _HistoryCardSkeletonState();
}

class _HistoryCardSkeletonState extends State<HistoryCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.shimmer,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      // Silent on purpose. Five placeholders announcing "Loading history" five
      // times says nothing four of them did not; [HistoryFeedSkeleton] makes
      // the announcement once for the whole run.
      child: Builder(
        builder: (context) => AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // The same slow two-tone pulse the rest of the app's skeletons use.
            final color = Color.lerp(
              scheme.surfaceContainerHighest,
              scheme.surfaceContainerLow,
              _controller.value,
            )!;
            return AppCard(
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: HistoryCard.thumbnailWidth,
                      height: HistoryCard.thumbnailHeight,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title, mode, metadata, date — the card's four lines,
                          // at their heights and in their order.
                          _Bar(color: color, widthFactor: .55, height: 16),
                          const SizedBox(height: AppSpacing.xxs),
                          _Bar(color: color, widthFactor: .35, height: 11),
                          const SizedBox(height: AppSpacing.xxs),
                          _Bar(color: color, widthFactor: .45, height: 12),
                          const SizedBox(height: AppSpacing.xxs),
                          _Bar(color: color, widthFactor: .4, height: 12),
                        ],
                      ),
                    ),
                    // Holds the column the overflow and chevron will occupy, so
                    // the text column keeps its real width while loading.
                    const SizedBox(
                      width: kMinInteractiveDimension,
                      height: HistoryCard.thumbnailHeight,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A run of [HistoryCardSkeleton]s spaced like real feed rows.
///
/// Used two ways: as the whole feed before any record has arrived, and as a
/// short tail while one of the two authorities is still loading and the other
/// has already produced cards. A tail is the honest place for it — it says
/// "more is coming" without claiming to know where those rows will sort.
class HistoryFeedSkeleton extends StatelessWidget {
  const HistoryFeedSkeleton({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) => SliverList(
    delegate: SliverChildBuilderDelegate((context, index) {
      const row = Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm),
        child: HistoryCardSkeleton(),
      );
      // Announced once, on the first row, rather than once per placeholder.
      return index == 0
          ? Semantics(label: 'Loading history', liveRegion: true, child: row)
          : row;
    }, childCount: count),
  );
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.color,
    required this.widthFactor,
    required this.height,
  });

  final Color color;
  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    alignment: Alignment.centerLeft,
    widthFactor: widthFactor,
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
    ),
  );
}
