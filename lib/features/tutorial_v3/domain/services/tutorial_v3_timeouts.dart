/// How long a V3 operation may run before the screen must stop waiting.
///
/// Two values, not one, because the two kinds of work are not comparable and a
/// single number would have to be wrong for one of them:
///
/// - **[session]** covers row reads, the entry RPC and storage signing. These
///   are ordinary round trips, and the rest of the app already bounds
///   comparable work in the 20–30 second band.
/// - **[ai]** covers planning and geometry mapping, which call Gemini through
///   an Edge Function. That function allows two attempts at 60 seconds each
///   plus backoff, so a *healthy but slow* generation can legitimately take
///   just over two minutes. A client timeout below that would abort work the
///   server was about to finish, spend the quota anyway, and look exactly like
///   a bug.
///
/// [defaultAiOperation] therefore sits above the server's own worst case and
/// at the platform's wall-clock ceiling for a function invocation: past this
/// point the request is dead regardless, so waiting longer only prolongs a
/// spinner.
///
/// Injectable so tests can drive the timeout path in milliseconds rather than
/// waiting out a production duration.
class TutorialV3Timeouts {
  const TutorialV3Timeouts({
    this.session = defaultSessionOperation,
    this.ai = defaultAiOperation,
  });

  /// Session open, reopen, plan read-back, and image signing.
  static const defaultSessionOperation = Duration(seconds: 20);

  /// Planning and geometry mapping.
  static const defaultAiOperation = Duration(seconds: 150);

  final Duration session;
  final Duration ai;
}
