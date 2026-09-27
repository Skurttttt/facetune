import '../data_sources/makeup_kit_look_remote_data_source.dart';
import '../data_sources/pdmk_pending_request_store.dart';
import 'pdmk_preview_operation_driver.dart';

/// Continues a plan-driven preview the app was waiting on when it was killed
/// or backgrounded.
///
/// The request is already paid for — its AI Look is reserved — so carrying it
/// to an answer is what the user asked for, not new work: an accepted preview
/// lands in History, a failure releases the hold and is forgotten. Only the
/// signed-in user's own pending operation is ever read. Every error is
/// swallowed, because the operation stays pending and the next resume, or the
/// next preview request, continues it.
class PdmkPendingPreviewResumer {
  PdmkPendingPreviewResumer({
    required MakeupKitLookRemoteDataSource remote,
    required PdmkPendingRequestStore store,
    Duration callTimeout = const Duration(seconds: 180),
  }) : _remote = remote,
       _store = store,
       _callTimeout = callTimeout;

  final MakeupKitLookRemoteDataSource _remote;
  final PdmkPendingRequestStore _store;
  final Duration _callTimeout;
  Future<void>? _running;

  /// Resumes the current user's pending preview, if any. Calls made while one
  /// is running join it rather than replaying the operation twice.
  Future<void> resume() => _running ??= _resume().whenComplete(() {
    _running = null;
  });

  Future<void> _resume() async {
    final userId = _remote.currentUserId;
    if (userId == null) return;
    try {
      final pending = await _store.pendingPreview(userId: userId);
      if (pending == null) return;
      await PdmkPreviewOperationDriver(
        remote: _remote,
        store: _store,
        callTimeout: _callTimeout,
      ).drive(pending);
    } catch (_) {}
  }
}
