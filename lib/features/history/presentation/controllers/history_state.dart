import '../../domain/entities/history_entry.dart';

enum HistoryLoadStatus { loading, ready, loadingMore, failure }

class HistoryState {
  const HistoryState({
    this.status = HistoryLoadStatus.loading,
    this.items = const [],
    this.filter = HistoryFilter.all,
    this.query = '',
    this.hasMore = true,
    this.nextOffset = 0,
    this.mutatingIds = const {},
    this.message,
    this.feedback,
    this.feedbackIsError = false,
    this.sessionExpired = false,
  });

  final HistoryLoadStatus status;
  final List<HistoryEntry> items;
  final HistoryFilter filter;
  final String query;
  final bool hasMore;
  final int nextOffset;
  final Set<String> mutatingIds;
  final String? message;
  final String? feedback;
  final bool feedbackIsError;
  final bool sessionExpired;

  List<HistoryEntry> get visibleItems {
    final normalizedQuery = query.trim().toLowerCase();
    return items
        .where((entry) {
          final matchesFilter = switch (filter) {
            HistoryFilter.all => true,
            HistoryFilter.completed =>
              entry.status == HistoryCompletionStatus.complete,
            HistoryFilter.favorites => entry.isFavorite,
          };
          if (!matchesFilter) return false;
          if (normalizedQuery.isEmpty) return true;
          final attributes = entry.analysis.attributes;
          final searchable = [
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
          return searchable.contains(normalizedQuery);
        })
        .toList(growable: false);
  }
}
