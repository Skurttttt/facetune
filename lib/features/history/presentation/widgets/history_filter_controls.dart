import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../domain/entities/history_entry.dart';
import '../models/history_feed_item.dart';

class HistoryFilterControls extends StatefulWidget {
  const HistoryFilterControls({
    required this.query,
    required this.typeFilter,
    required this.statusFilter,
    required this.onQueryChanged,
    required this.onTypeChanged,
    required this.onStatusChanged,
    super.key,
  });

  /// The search the feed is actually filtered by.
  ///
  /// The field used to be uncontrolled, so the text lived only in the widget's
  /// own element while the filter lived in the controller. Anything that
  /// rebuilt the field from scratch left an empty search box over a filtered
  /// feed. Seeding from the authoritative value keeps the two in step, and is
  /// what lets the query survive a return from an opened record.
  final String query;

  final HistoryFeedTypeFilter typeFilter;
  final HistoryFilter statusFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<HistoryFeedTypeFilter> onTypeChanged;
  final ValueChanged<HistoryFilter> onStatusChanged;

  @override
  State<HistoryFilterControls> createState() => _HistoryFilterControlsState();
}

class _HistoryFilterControlsState extends State<HistoryFilterControls> {
  late final TextEditingController _query = TextEditingController(
    text: widget.query,
  );

  @override
  void didUpdateWidget(HistoryFilterControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only when the value changed somewhere other than this field — otherwise
    // every keystroke would rewrite the text and drop the caret to the end.
    if (widget.query != _query.text) _query.text = widget.query;
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // The hint is the only thing naming this field, and a hint disappears the
      // moment there is text in it — so anyone arriving at a filled search box
      // with a screen reader would hear the query and never learn what it was
      // for. The label is carried in semantics rather than as a visible
      // `labelText` so the control looks exactly as it did.
      Semantics(
        label: 'Search your history',
        textField: true,
        child: TextField(
          controller: _query,
          onChanged: widget.onQueryChanged,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search your history',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      const _FilterLabel('TYPE'),
      const SizedBox(height: AppSpacing.xs),
      // One row that scrolls, rather than a `Wrap` that folds.
      //
      // "All", "My Makeup Kit" and "Recommendations" need more width than a
      // phone's content column has, so `Wrap` did what it is for and dropped
      // the third chip onto a run of its own — which reads as a second group
      // rather than the tail of this one, and costs a whole row of height
      // above the feed. The three chips are one set of alternatives, so they
      // stay on one line and the line moves instead.
      //
      // STATUS keeps its `Wrap`: its three labels fit, and it has no reason to
      // scroll.
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          spacing: AppSpacing.xs,
          children: [
            for (final filter in HistoryFeedTypeFilter.values)
              FilterChip(
                label: Text(filter.label),
                selected: widget.typeFilter == filter,
                onSelected: (_) => widget.onTypeChanged(filter),
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      // No Sort control, and deliberately nothing in its place. The feed is
      // always newest first, which is the order the date headings below already
      // announce — a control whose only remaining job was to restate the
      // default was one more thing to read past on the way to the filters.
      const _FilterLabel('STATUS'),
      const SizedBox(height: AppSpacing.xs),
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final filter in HistoryFilter.values)
            FilterChip(
              label: Text(_statusLabel(filter)),
              selected: widget.statusFilter == filter,
              onSelected: (_) => widget.onStatusChanged(filter),
            ),
        ],
      ),
    ],
  );

  static String _statusLabel(HistoryFilter filter) => switch (filter) {
    HistoryFilter.all => 'All',
    HistoryFilter.completed => 'Completed',
    HistoryFilter.favorites => 'Favorites',
  };
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel(this.label);

  final String label;

  // A header, so a screen reader can jump between the filter groups instead of
  // walking every chip to find where TYPE ends and STATUS begins.
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
