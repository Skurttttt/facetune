import '../../domain/entities/saved_look.dart';

enum SavedLooksStatus { loading, ready, loadingMore, failure }

class SavedLooksState {
  const SavedLooksState({
    this.status = SavedLooksStatus.loading,
    this.items = const [],
    this.hasMore = true,
    this.message,
  });

  final SavedLooksStatus status;
  final List<SavedLook> items;
  final bool hasMore;
  final String? message;
}
