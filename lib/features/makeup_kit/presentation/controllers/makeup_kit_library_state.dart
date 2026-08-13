import '../../domain/entities/kit_look_result.dart';

enum MakeupKitLibraryStatus { loading, ready, loadingMore, failure }

class MakeupKitSavedState {
  const MakeupKitSavedState({
    this.status = MakeupKitLibraryStatus.loading,
    this.items = const [],
    this.hasMore = true,
    this.mutatingIds = const {},
    this.message,
    this.feedback,
    this.sessionExpired = false,
  });

  final MakeupKitLibraryStatus status;
  final List<KitSavedLook> items;
  final bool hasMore;
  final Set<String> mutatingIds;
  final String? message;
  final String? feedback;
  final bool sessionExpired;
}

class MakeupKitHistoryState {
  const MakeupKitHistoryState({
    this.status = MakeupKitLibraryStatus.loading,
    this.items = const [],
    this.hasMore = true,
    this.mutatingIds = const {},
    this.message,
    this.feedback,
    this.sessionExpired = false,
  });

  final MakeupKitLibraryStatus status;
  final List<KitHistoryEntry> items;
  final bool hasMore;
  final Set<String> mutatingIds;
  final String? message;
  final String? feedback;
  final bool sessionExpired;
}
