import 'dart:async';

import '../../../preview/domain/errors/preview_failure.dart';
import '../data_sources/makeup_kit_look_remote_data_source.dart';
import '../data_sources/pdmk_pending_request_store.dart';

/// Carries one pending plan-driven preview operation to a terminal answer.
///
/// The server may need several invocations for one logical request, so a
/// reply of `in_progress` is not an answer: the same operation id is sent
/// again after the server's suggested pause. The pending record is forgotten
/// only when the server says `accepted` or `failed`. A timeout, a lost
/// connection, a retryable error, or running out of patience keeps it, so the
/// next attempt — after a retry, a restart, or a process death — continues
/// the same request and the same reservation.
class PdmkPreviewOperationDriver {
  PdmkPreviewOperationDriver({
    required MakeupKitLookRemoteDataSource remote,
    required PdmkPendingRequestStore store,
    required Duration callTimeout,
    Duration patience = const Duration(minutes: 8),
    Future<void> Function(Duration)? delay,
    DateTime Function()? now,
  }) : _remote = remote,
       _store = store,
       _callTimeout = callTimeout,
       _patience = patience,
       _delay = delay ?? Future<void>.delayed,
       _now = now ?? DateTime.now;

  final MakeupKitLookRemoteDataSource _remote;
  final PdmkPendingRequestStore _store;
  final Duration _callTimeout;
  final Duration _patience;
  final Future<void> Function(Duration) _delay;
  final DateTime Function() _now;

  static const _defaultPause = Duration(seconds: 5);
  static const _longestPause = Duration(seconds: 60);

  /// Replays [operation] until it is accepted, returning the accepted reply.
  ///
  /// Throws the remote failure when the server ends the operation (after
  /// forgetting it), or leaves it pending and throws when the reply is not
  /// authoritative.
  Future<Object?> drive(PendingPreviewOperation operation) async {
    final giveUpAt = _now().add(_patience);
    while (true) {
      Duration pause;
      try {
        final reply = await _remote
            .generatePreview(
              kitRecommendationId: operation.kitRecommendationId,
              operationId: operation.operationId,
            )
            .timeout(_callTimeout);
        final state = _operation(reply)?['state'];
        if (state != 'in_progress') {
          await _forget(operation);
          return reply;
        }
        pause = _pauseFrom(_operation(reply)?['retryAfterMs']);
      } on MakeupKitLookRemoteFailure catch (failure) {
        if (failure.operationState == 'failed') {
          await _forget(operation);
          rethrow;
        }
        if (failure.operationState != 'in_progress') rethrow;
        pause = _pauseFrom(failure.retryAfterMs);
      }
      if (!_now().add(pause).isBefore(giveUpAt)) {
        throw const PreviewFailure(
          PreviewFailureType.server,
          'Your preview is still being prepared. Try again in a moment.',
          retryable: true,
          technicalCode: 'PREVIEW_IN_PROGRESS',
        );
      }
      await _delay(pause);
    }
  }

  static Map<Object?, Object?>? _operation(Object? reply) {
    if (reply is! Map) return null;
    final operation = reply['operation'];
    return operation is Map ? operation : null;
  }

  static Duration _pauseFrom(Object? retryAfterMs) {
    if (retryAfterMs is! num) return _defaultPause;
    final pause = Duration(milliseconds: retryAfterMs.toInt());
    if (pause.isNegative) return Duration.zero;
    return pause > _longestPause ? _longestPause : pause;
  }

  /// Best effort: a record whose clear is lost replays to the same answer.
  Future<void> _forget(PendingPreviewOperation operation) async {
    try {
      await _store.clearPreview(operation);
    } catch (_) {}
  }
}
