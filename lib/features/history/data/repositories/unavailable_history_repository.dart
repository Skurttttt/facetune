import '../../domain/entities/history_entry.dart';
import '../../domain/errors/history_failure.dart';
import '../../domain/repositories/history_repository.dart';

class UnavailableHistoryRepository implements HistoryRepository {
  const UnavailableHistoryRepository();

  @override
  Future<void> deleteSession(String analysisId) =>
      throw const HistoryFailure('History is unavailable in this build.');

  @override
  Future<HistoryPageResult> loadPage({
    required int offset,
    required int limit,
  }) => throw const HistoryFailure('History is unavailable in this build.');
}
