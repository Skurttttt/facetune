/// Why a tutorial operation failed.
///
/// Modelled after the shipped `MakeupKitFailureKind` so the presentation layer
/// can treat tutorial failures with the same retry/session-expiry conventions
/// already used elsewhere in the app, plus the kinds unique to V4.
enum TutorialFailureKind {
  offline,
  timeout,
  sessionExpired,
  validation,
  notFound,
  unavailable,

  /// A category outside the controlled vocabulary was supplied — typically an
  /// AI response naming a category the application does not define.
  unsupportedCategory,

  /// The visual manifest could not be produced or accepted, so there is no
  /// grounded basis for deciding which steps a tutorial should contain.
  ///
  /// The system fails here rather than falling back to a generic step list.
  manifestUnavailable,

  /// The canonical final preview visibly contains a makeup category that has no
  /// corresponding validated owned-product selection.
  ///
  /// Never resolved by inventing a product, and never resolved by silently
  /// falling back to Standard Mode. The preview is not a valid canonical My
  /// Makeup Kit result until the inconsistency is resolved.
  kitPreviewMismatch,

  /// Guideline rendering for one step failed.
  stepGenerationFailed,

  /// A server-enforced AI usage quota rejected the request.
  quotaExceeded,

  /// The server refused to generate a NEW tutorial because the account's
  /// governing plan does not include the Step-by-Step Tutorial, or because
  /// the look was created with a Final Preview Credit, which never carries
  /// one. Not retryable: nothing the client does changes the plan.
  ///
  /// Historical tutorials are never refused this way — an already-generated
  /// manifest or step is returned before the server decides anything.
  notIncluded,

  unknown,
}

class TutorialFailure implements Exception {
  const TutorialFailure(
    this.message, {
    this.kind = TutorialFailureKind.unknown,
    this.retryable = true,
  });

  /// A user-safe message. Never carries prompts, model output, storage paths,
  /// or any other sensitive diagnostic detail.
  final String message;
  final TutorialFailureKind kind;
  final bool retryable;

  @override
  String toString() => message;
}
