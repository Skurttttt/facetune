import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_remote_data_source.dart';
import '../../domain/errors/tutorial_v3_failure.dart';

/// The Edge Function surface for Tutorial V3.
///
/// Kept separate from [TutorialV3RemoteDataSource], which is the Postgres
/// surface. These two calls are the only places the client asks the server to
/// *do* something rather than read or write a row.
///
/// Both requests carry **identifiers only**. The server resolves the analysis,
/// the selfie, the Step Spec, the face attributes, the category, the Kit
/// product and every version from persisted rows under the caller's own JWT
/// (V3-6B §3.1). A client that sent anything else would be refused with
/// `unsupported_field`, so there is no shape here for one to grow into.
abstract interface class TutorialV3FunctionDataSource {
  /// Asks the server to plan the tutorial for [sessionId] and persist it.
  ///
  /// Returns the raw response body. The plan itself is read back from the
  /// database rather than trusted from this payload.
  Future<Map<String, Object?>> plan({required String sessionId});

  /// Asks the server to map geometry for one step.
  ///
  /// Returns the raw response body: `{status, reused, schemaVersion,
  /// geometry, ...}`. The document is validated on this side before it is
  /// used, so a malformed response is rejected rather than rendered.
  Future<Map<String, Object?>> mapGeometry({
    required String sessionId,
    required int stepIndex,
  });
}

class SupabaseTutorialV3FunctionDataSource extends SupabaseRemoteDataSource
    implements TutorialV3FunctionDataSource {
  const SupabaseTutorialV3FunctionDataSource(super.client);

  static const planFunction = 'plan-tutorial-v3';
  static const geometryFunction = 'map-tutorial-v3-guideline-geometry';

  @override
  Future<Map<String, Object?>> plan({required String sessionId}) => _invoke(
    planFunction,
    <String, Object?>{'sessionId': sessionId},
    'This tutorial could not be planned.',
  );

  @override
  Future<Map<String, Object?>> mapGeometry({
    required String sessionId,
    required int stepIndex,
  }) => _invoke(
    geometryFunction,
    // Exactly two identifiers. Never the Step Spec, the category, the
    // analysis, a storage path, a prompt, or the geometry of any other step.
    <String, Object?>{'sessionId': sessionId, 'stepIndex': stepIndex},
    'This step could not be prepared.',
  );

  Future<Map<String, Object?>> _invoke(
    String name,
    Map<String, Object?> body,
    String fallbackMessage,
  ) async {
    try {
      final response = await client.functions.invoke(name, body: body);
      final data = response.data;
      if (data is Map) return data.cast<String, Object?>();
      throw TutorialV3Failure(
        fallbackMessage,
        kind: TutorialV3FailureKind.unknown,
        retryable: true,
      );
    } on FunctionException catch (error) {
      throw _failure(error, fallbackMessage);
    }
  }

  /// Translates the function's `{error: {code, message, retryable}}` body into
  /// the domain failure, preserving the server's own wording and its retry
  /// verdict rather than guessing at either.
  TutorialV3Failure _failure(FunctionException error, String fallbackMessage) {
    final details = error.details;
    final root = details is Map
        ? details.map((key, value) => MapEntry(key.toString(), value))
        : const <String, Object?>{};
    final nested = root['error'];
    final payload = nested is Map
        ? nested.map((key, value) => MapEntry(key.toString(), value))
        : root;
    final code = payload['code']?.toString() ?? '';
    final message = payload['message']?.toString() ?? fallbackMessage;
    final failure = TutorialV3Failure(
      message,
      kind: _kindFor(error.status, code),
      // The server decides what may be retried. A client that retried a
      // validation failure would just burn the step's bounded attempts.
      retryable: payload['retryable'] == true,
    );
    _logFailure(code, error.status, failure);
    return failure;
  }

  /// Records which server failure this was, in debug builds only.
  ///
  /// Without this a rejected function call reached the screen as a sentence
  /// with no way to tell `gemini_rate_limited` from `gemini_upstream_error`
  /// from `incompatible_plan_version` — every one of which needs a different
  /// response from whoever is debugging. The failure was translated correctly
  /// and reported to the user correctly, and left no trace anywhere.
  ///
  /// Only the server's own `code`, its HTTP status and the derived
  /// classification. Never the response body, the request, or any header:
  /// those carry the caller's JWT and the function's own payload.
  static void _logFailure(String code, int status, TutorialV3Failure failure) {
    if (!kDebugMode) return;
    debugPrint(
      '[tutorial_v3] edge function rejected: '
      'status=$status code=${code.isEmpty ? 'none' : code} '
      'kind=${failure.kind.name} retryable=${failure.retryable}',
    );
  }

  TutorialV3FailureKind _kindFor(int status, String code) {
    switch (code) {
      case 'authentication_required':
        return TutorialV3FailureKind.sessionExpired;
      case 'incompatible_plan_version':
      case 'incompatible_geometry_version':
        return TutorialV3FailureKind.validation;
      case 'inventory_changed':
      case 'recommendation_mismatch':
        return TutorialV3FailureKind.ownership;
      case 'gemini_timeout':
        return TutorialV3FailureKind.timeout;
    }
    if (status == 401 || status == 403) return TutorialV3FailureKind.ownership;
    if (status == 404) return TutorialV3FailureKind.notFound;
    if (status == 409) return TutorialV3FailureKind.validation;
    if (status == 422) return TutorialV3FailureKind.generation;
    if (status == 429 || status == 503) {
      return TutorialV3FailureKind.unavailable;
    }
    if (status == 504) return TutorialV3FailureKind.timeout;
    return TutorialV3FailureKind.unknown;
  }
}
