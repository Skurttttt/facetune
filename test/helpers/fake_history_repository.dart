import 'package:facetune/features/history/domain/entities/history_entry.dart';
import 'package:facetune/features/history/domain/errors/history_failure.dart';
import 'package:facetune/features/history/domain/repositories/history_repository.dart';

class FakeHistoryRepository implements HistoryRepository {
  FakeHistoryRepository({this.items = const [], this.failure});

  final List<HistoryEntry> items;
  final HistoryFailure? failure;
  int loadCount = 0;

  @override
  Future<HistoryPageResult> loadPage({
    required int offset,
    required int limit,
  }) async {
    loadCount += 1;
    final currentFailure = failure;
    if (currentFailure != null) throw currentFailure;
    final end = offset + limit < items.length ? offset + limit : items.length;
    final page = offset >= items.length
        ? const <HistoryEntry>[]
        : items.sublist(offset, end);
    return HistoryPageResult(
      items: page,
      hasMore: end < items.length,
      nextOffset: end,
    );
  }

  @override
  Future<void> deleteSession(String analysisId) async {}
}
