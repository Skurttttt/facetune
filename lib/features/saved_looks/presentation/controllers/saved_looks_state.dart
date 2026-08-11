import '../../domain/entities/saved_look.dart';

enum SavedLooksStatus { loading, ready, loadingMore, failure }

class SavedLooksState {
  const SavedLooksState({
    this.status = SavedLooksStatus.loading,
    this.items = const [],
    this.hasMore = true,
    this.mutatingIds = const {},
    this.message,
    this.feedback,
    this.feedbackIsError = false,
    this.sessionExpired = false,
  });

  final SavedLooksStatus status;
  final List<SavedLook> items;
  final bool hasMore;
  final Set<String> mutatingIds;
  final String? message;
  final String? feedback;
  final bool feedbackIsError;
  final bool sessionExpired;
}
