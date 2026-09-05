import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../models/history_feed_item.dart';

typedef HistoryFeedItemBuilder =
    Widget Function(BuildContext context, HistoryFeedItem item);

/// One lazily rendered chronological feed for both History record types.
///
/// Cards remain mode-specific until the shared-card phase. This widget owns
/// only feed rhythm and date headings; [itemBuilder] preserves each mode's
/// existing callbacks and card implementation.
class HistoryFeed extends StatelessWidget {
  const HistoryFeed({
    required this.items,
    required this.sort,
    required this.itemBuilder,
    this.now,
    super.key,
  });

  final List<HistoryFeedItem> items;
  final HistoryFeedSort sort;
  final HistoryFeedItemBuilder itemBuilder;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final rows = sort == HistoryFeedSort.styleAscending
        ? <_HistoryFeedRow>[for (final item in items) _HistoryFeedEntry(item)]
        : <_HistoryFeedRow>[
            for (final section in groupHistoryFeed(
              items,
              now: now,
              oldestFirst: sort == HistoryFeedSort.oldest,
            )) ...[
              _HistoryFeedHeading(section.group),
              for (final item in section.items) _HistoryFeedEntry(item),
            ],
          ];

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final row = rows[index];
        return switch (row) {
          _HistoryFeedHeading(:final group) => Padding(
            padding: EdgeInsets.only(
              top: index == 0 ? 0 : AppSpacing.lg,
              bottom: AppSpacing.sm,
            ),
            child: Semantics(
              header: true,
              child: Text(
                group.label,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          _HistoryFeedEntry(:final item) => Padding(
            key: ValueKey(item.presentationKey),
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: itemBuilder(context, item),
          ),
        };
      }, childCount: rows.length),
    );
  }
}

sealed class _HistoryFeedRow {
  const _HistoryFeedRow();
}

final class _HistoryFeedHeading extends _HistoryFeedRow {
  const _HistoryFeedHeading(this.group);

  final HistoryDateGroup group;
}

final class _HistoryFeedEntry extends _HistoryFeedRow {
  const _HistoryFeedEntry(this.item);

  final HistoryFeedItem item;
}
