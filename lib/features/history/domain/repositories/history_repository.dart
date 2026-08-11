import '../entities/history_entry.dart';

abstract interface class HistoryRepository {
  Future<HistoryPageResult> loadPage({required int offset, required int limit});

  Future<void> deleteSession(String analysisId);
}
