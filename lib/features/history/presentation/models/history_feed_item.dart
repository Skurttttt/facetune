import '../../../makeup_kit/domain/entities/kit_look_result.dart';
import '../../domain/entities/history_entry.dart';

/// The authoritative source represented by one row in the shared History feed.
///
/// This is presentation vocabulary only. The two repositories and controllers
/// remain separate, and adapters below never fill one mode from the other.
enum HistoryFeedRecordType { recommendation, myMakeupKit }

enum HistoryFeedTypeFilter { all, myMakeupKit, recommendations }

extension HistoryFeedTypeFilterLabel on HistoryFeedTypeFilter {
  String get label => switch (this) {
    HistoryFeedTypeFilter.all => 'All',
    HistoryFeedTypeFilter.myMakeupKit => 'My Makeup Kit',
    HistoryFeedTypeFilter.recommendations => 'Recommendations',
  };
}

/// Every sort option backed by an authoritative field in both History modes.
///
/// There is deliberately no "Recently viewed": neither source has a persisted
/// view timestamp, so offering it would invent ordering data.
enum HistoryFeedSort { newest, oldest, styleAscending }

extension HistoryFeedSortLabel on HistoryFeedSort {
  String get label => switch (this) {
    HistoryFeedSort.newest => 'Newest first',
    HistoryFeedSort.oldest => 'Oldest first',
    HistoryFeedSort.styleAscending => 'Style A-Z',
  };
}

/// A presentation-only reference to one existing History record.
sealed class HistoryFeedItem {
  const HistoryFeedItem({
    required this.recordType,
    required this.stableId,
    required this.occurredAt,
  });

  final HistoryFeedRecordType recordType;
  final String stableId;
  final DateTime occurredAt;

  String get styleName;
  bool get isComplete;
  bool get isFavorite;
  String get searchableText;

  /// The already-signed image this mode's own authority loaded for the record.
  String get thumbnailUrl;

  /// Which authority this row came from, said plainly to the user.
  String get modeLabel;

  /// The one supporting fact this mode can truthfully state about the record.
  ///
  /// Standard reports its own completion status; My Kit reports its own owned
  /// product count. Neither is ever derived from the other.
  String get metadataLabel;

  /// Unique even when Standard and My Kit were created from the same analysis.
  String get presentationKey => '${recordType.name}:$stableId';
}

/// Thin adapter for the existing Standard History authority.
final class StandardHistoryFeedItem extends HistoryFeedItem {
  StandardHistoryFeedItem(this.entry)
    : super(
        recordType: HistoryFeedRecordType.recommendation,
        stableId: entry.id,
        // This is the timestamp the current Standard card already presents.
        occurredAt: entry.latestActivityAt,
      );

  final HistoryEntry entry;

  @override
  String get styleName => entry.style?.name ?? 'Beauty analysis';

  @override
  bool get isComplete => entry.status == HistoryCompletionStatus.complete;

  @override
  bool get isFavorite => entry.isFavorite;

  @override
  String get thumbnailUrl => entry.thumbnailUrl;

  @override
  String get modeLabel => 'Recommendation';

  /// The existing Standard completion labels, unchanged. HIST-UI-3 moves this
  /// text out of a coloured pill and into quiet metadata; it does not restate
  /// or reinterpret the underlying status value.
  @override
  String get metadataLabel => switch (entry.status) {
    HistoryCompletionStatus.analysisReady => 'Analysis',
    HistoryCompletionStatus.recommendationReady => 'Plan ready',
    HistoryCompletionStatus.complete => 'Complete',
  };

  @override
  String get searchableText {
    final attributes = entry.analysis.attributes;
    return [
      entry.style?.name,
      entry.style?.code,
      entry.recommendation?.overallIntensity,
      attributes.faceShape.name,
      attributes.skinTone.name,
      attributes.undertone.name,
      attributes.eyeShape.name,
      attributes.lipShape.name,
      attributes.hairColor.name,
      attributes.eyeColor.name,
      entry.status.name,
    ].whereType<String>().join(' ').toLowerCase();
  }
}

/// Thin adapter for the existing immutable My Makeup Kit History authority.
final class MyMakeupKitHistoryFeedItem extends HistoryFeedItem {
  MyMakeupKitHistoryFeedItem(this.entry)
    : super(
        recordType: HistoryFeedRecordType.myMakeupKit,
        // One analysis can own multiple kit preview variations. The preview id
        // identifies the actual History record without colliding with Standard.
        stableId: entry.id,
        occurredAt: entry.result.preview.createdAt,
      );

  final KitHistoryEntry entry;

  @override
  String get styleName => entry.result.style.name;

  @override
  bool get isComplete => true;

  @override
  bool get isFavorite => entry.isFavorite;

  @override
  String get thumbnailUrl => entry.result.preview.generatedImageUrl;

  @override
  String get modeLabel => 'My Makeup Kit';

  /// `selections` is the app's existing owned-product count authority — the
  /// same field the kit result screen and the kit saved-look card already read.
  /// The snapshots beside it are the immutable record of those products, not a
  /// second count, and Standard has no equivalent field to fall back to.
  @override
  String get metadataLabel {
    final count = entry.result.recommendation.selections.length;
    return '$count owned product${count == 1 ? '' : 's'}';
  }

  @override
  String get searchableText {
    final result = entry.result;
    final attributes = result.analysis.attributes;
    return [
      result.style.name,
      result.style.code,
      result.recommendation.overallIntensity,
      result.recommendation.summary,
      ...result.recommendation.productSnapshots.expand(
        (snapshot) => [
          snapshot.category,
          snapshot.productName,
          snapshot.colorLabel,
          snapshot.colorHex,
          snapshot.finish,
          snapshot.foundationDepth,
          snapshot.foundationUndertone,
        ],
      ),
      attributes.faceShape.name,
      attributes.skinTone.name,
      attributes.undertone.name,
      attributes.eyeShape.name,
      attributes.lipShape.name,
      attributes.hairColor.name,
      attributes.eyeColor.name,
    ].whereType<String>().join(' ').toLowerCase();
  }
}

/// Adapts and orders the two authorities without merging either repository.
List<HistoryFeedItem> buildHistoryFeed({
  required List<HistoryEntry> recommendations,
  required List<KitHistoryEntry> myMakeupKit,
  HistoryFeedTypeFilter typeFilter = HistoryFeedTypeFilter.all,
  HistoryFilter statusFilter = HistoryFilter.all,
  String query = '',
  HistoryFeedSort sort = HistoryFeedSort.newest,
}) {
  final candidates = <HistoryFeedItem>[
    for (final entry in recommendations) StandardHistoryFeedItem(entry),
    for (final entry in myMakeupKit) MyMakeupKitHistoryFeedItem(entry),
  ];
  final normalizedQuery = query.trim().toLowerCase();
  final uniqueItems = <String, HistoryFeedItem>{};
  for (final item in candidates) {
    if (!_matchesType(item, typeFilter) ||
        !_matchesStatus(item, statusFilter) ||
        (normalizedQuery.isNotEmpty &&
            !item.searchableText.contains(normalizedQuery))) {
      continue;
    }
    uniqueItems.putIfAbsent(item.presentationKey, () => item);
  }
  final items = uniqueItems.values.toList(growable: false)
    ..sort((left, right) => _compareFeedItems(left, right, sort));
  return List.unmodifiable(items);
}

bool _matchesType(HistoryFeedItem item, HistoryFeedTypeFilter filter) =>
    switch (filter) {
      HistoryFeedTypeFilter.all => true,
      HistoryFeedTypeFilter.myMakeupKit =>
        item.recordType == HistoryFeedRecordType.myMakeupKit,
      HistoryFeedTypeFilter.recommendations =>
        item.recordType == HistoryFeedRecordType.recommendation,
    };

bool _matchesStatus(HistoryFeedItem item, HistoryFilter filter) =>
    switch (filter) {
      HistoryFilter.all => true,
      HistoryFilter.completed => item.isComplete,
      HistoryFilter.favorites => item.isFavorite,
    };

int _compareFeedItems(
  HistoryFeedItem left,
  HistoryFeedItem right,
  HistoryFeedSort sort,
) {
  final byTime = switch (sort) {
    HistoryFeedSort.newest => right.occurredAt.compareTo(left.occurredAt),
    HistoryFeedSort.oldest => left.occurredAt.compareTo(right.occurredAt),
    HistoryFeedSort.styleAscending => left.styleName.toLowerCase().compareTo(
      right.styleName.toLowerCase(),
    ),
  };
  if (byTime != 0) return byTime;

  // Explicit type order and stable id make equal timestamps deterministic and
  // independent of whichever repository happened to finish loading first.
  final byType = left.recordType.index.compareTo(right.recordType.index);
  if (byType != 0) return byType;
  return left.stableId.compareTo(right.stableId);
}

/// Why the feed came back empty.
///
/// An empty feed is four different situations wearing one shape, and they call
/// for four different sentences. "No history yet" in front of someone who has
/// twenty sessions and a search term typed is simply wrong, and it hides the
/// fact that clearing the search is what fixes it.
enum HistoryEmptyReason {
  noHistory,
  noMyMakeupKitHistory,
  noFavorites,
  noMatches,
}

extension HistoryEmptyReasonCopy on HistoryEmptyReason {
  String get title => switch (this) {
    HistoryEmptyReason.noHistory => 'No history yet',
    HistoryEmptyReason.noMyMakeupKitHistory => 'No My Makeup Kit history yet',
    HistoryEmptyReason.noFavorites => 'No favorites yet',
    HistoryEmptyReason.noMatches => 'No matches found',
  };

  String get message => switch (this) {
    HistoryEmptyReason.noHistory => 'Looks you create will appear here.',
    HistoryEmptyReason.noMyMakeupKitHistory =>
      'Looks created with products from your kit will appear here.',
    HistoryEmptyReason.noFavorites =>
      'Favorite a look to keep it easy to find.',
    HistoryEmptyReason.noMatches => 'Try another search or clear your filters.',
  };
}

/// Chooses which of the four an empty feed actually is.
///
/// Ordered most-specific-act first. A search the user just typed explains the
/// emptiness better than any filter still sitting behind it, and two narrowing
/// filters at once explain it less well than either alone — so that case falls
/// through to "no matches", which points at the thing that fixes it.
HistoryEmptyReason resolveHistoryEmptyReason({
  required bool hasAnyRecords,
  required HistoryFeedTypeFilter typeFilter,
  required HistoryFilter statusFilter,
  required String query,
}) {
  if (query.trim().isNotEmpty) return HistoryEmptyReason.noMatches;
  final narrowsToKit = typeFilter == HistoryFeedTypeFilter.myMakeupKit;
  final narrowsToFavorites = statusFilter == HistoryFilter.favorites;
  if (narrowsToFavorites && !narrowsToKit) {
    return HistoryEmptyReason.noFavorites;
  }
  if (narrowsToKit && !narrowsToFavorites) {
    return HistoryEmptyReason.noMyMakeupKitHistory;
  }
  if (typeFilter == HistoryFeedTypeFilter.all &&
      statusFilter == HistoryFilter.all) {
    return hasAnyRecords
        ? HistoryEmptyReason.noMatches
        : HistoryEmptyReason.noHistory;
  }
  return HistoryEmptyReason.noMatches;
}

enum HistoryDateGroup { today, yesterday, thisWeek, earlier }

extension HistoryDateGroupLabel on HistoryDateGroup {
  String get label => switch (this) {
    HistoryDateGroup.today => 'Today',
    HistoryDateGroup.yesterday => 'Yesterday',
    HistoryDateGroup.thisWeek => 'This week',
    HistoryDateGroup.earlier => 'Earlier',
  };
}

class HistoryFeedSection {
  const HistoryFeedSection({required this.group, required this.items});

  final HistoryDateGroup group;
  final List<HistoryFeedItem> items;
}

/// Groups an already-authoritative feed by the user's local calendar.
List<HistoryFeedSection> groupHistoryFeed(
  List<HistoryFeedItem> items, {
  DateTime? now,
  bool oldestFirst = false,
}) {
  if (items.isEmpty) return const [];

  final localNow = (now ?? DateTime.now()).toLocal();
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
  final grouped = <HistoryDateGroup, List<HistoryFeedItem>>{};

  for (final item in items) {
    final local = item.occurredAt.toLocal();
    final date = DateTime(local.year, local.month, local.day);
    final group = switch (date) {
      _ when date == today => HistoryDateGroup.today,
      _ when date == yesterday => HistoryDateGroup.yesterday,
      _ when date.isBefore(today) && !date.isBefore(startOfWeek) =>
        HistoryDateGroup.thisWeek,
      _ => HistoryDateGroup.earlier,
    };
    (grouped[group] ??= <HistoryFeedItem>[]).add(item);
  }

  final orderedGroups = oldestFirst
      ? HistoryDateGroup.values.reversed
      : HistoryDateGroup.values;
  return List.unmodifiable([
    for (final group in orderedGroups)
      if (grouped[group] case final entries?)
        HistoryFeedSection(group: group, items: List.unmodifiable(entries)),
  ]);
}
