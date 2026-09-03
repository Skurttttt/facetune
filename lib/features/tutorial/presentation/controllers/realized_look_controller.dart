import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/canonical_preview_ref.dart';
import '../../domain/entities/tutorial_category.dart';
import '../../domain/entities/tutorial_session.dart';
import '../../domain/errors/tutorial_failure.dart';
import '../../domain/usecases/resolve_tutorial_manifest.dart';

/// What the realized-look manifest is doing right now.
///
/// [ensuring] exists so the breakdown can wait rather than render the
/// unfiltered recommendation and correct itself a moment later. A screen that
/// says nine and then says eight has told the user something false, and the
/// fact that it was only false briefly does not help them.
enum RealizedLookStatus { idle, ensuring, ready, failed, kitPreviewMismatch }

/// The accepted manifest for one canonical preview, as the result page needs it.
class RealizedLookState {
  const RealizedLookState({
    this.status = RealizedLookStatus.idle,
    this.preview,
    this.session,
    this.message,
    this.retryable = true,
  });

  final RealizedLookStatus status;

  /// The canonical preview this state describes. Held so a stale result for a
  /// previous preview can never be presented against a new one.
  final CanonicalPreviewRef? preview;

  final TutorialSession? session;
  final String? message;
  final bool retryable;

  /// The visibly present categories, in deterministic vocabulary order.
  ///
  /// Empty unless the manifest is ready. That is deliberate: an empty list here
  /// must never be mistaken for "this look contains nothing", which is why
  /// every consumer branches on [status] first.
  List<TutorialCategory> get includedCategories =>
      status == RealizedLookStatus.ready
      ? (session?.includedCategories ?? const <TutorialCategory>[])
      : const <TutorialCategory>[];

  bool get isReady => status == RealizedLookStatus.ready;

  RealizedLookState copyWith({
    RealizedLookStatus? status,
    CanonicalPreviewRef? preview,
    TutorialSession? session,
    String? message,
    bool clearMessage = false,
    bool? retryable,
  }) => RealizedLookState(
    status: status ?? this.status,
    preview: preview ?? this.preview,
    session: session ?? this.session,
    message: clearMessage ? null : (message ?? this.message),
    retryable: retryable ?? this.retryable,
  );
}

/// Ensures exactly one accepted manifest per canonical final preview, and
/// hands its category set to whoever presents the realized look.
///
/// This is the single category-inclusion authority. Both consumers now read the
/// same accepted manifest: the Makeup Breakdown through this controller, and
/// the tutorial through [TutorialController] — and crucially, through the *same*
/// [ResolveTutorialManifest] use case, not a parallel copy of its rules. There
/// is one manifest concept and one place that decides what is in it.
///
/// **Why this cannot double-charge.** [ResolveTutorialManifest] checks for a
/// persisted session, then for an accepted manifest, and only analyses when
/// neither exists. So whichever consumer arrives first pays once, and every
/// later arrival — the tutorial opening, a History reopen, a rebuild — resolves
/// from persistence. The server reuses as well, so the guarantee holds even if
/// two clients race.
///
/// A `StateNotifier` rather than a `FutureProvider` for the same reason the
/// tutorial controller is one: a `FutureProvider` runs on first watch, which
/// would let a widget rebuild start paid analysis. This starts idle and does
/// nothing until [ensure] is called with a real preview.
class RealizedLookController extends StateNotifier<RealizedLookState> {
  RealizedLookController({required ResolveTutorialManifest resolveManifest})
    : _resolveManifest = resolveManifest,
      super(const RealizedLookState());

  final ResolveTutorialManifest _resolveManifest;

  CanonicalPreviewRef? _ensured;
  Future<void>? _inFlight;

  /// Ensures an accepted manifest for [preview], at most once.
  ///
  /// Idempotent in three ways, because this is called from a post-frame
  /// callback on a page that rebuilds freely: a completed preview short
  /// circuits, a concurrent call awaits the same future rather than starting a
  /// second, and a different preview resets first so two looks' state never
  /// blend.
  Future<void> ensure(CanonicalPreviewRef preview) {
    if (_ensured == preview && state.status != RealizedLookStatus.failed) {
      return Future<void>.value();
    }
    if (_ensured != null && _ensured != preview) {
      _inFlight = null;
      state = const RealizedLookState();
    }
    if (_inFlight != null) return _inFlight!;
    return _inFlight = _ensure(preview).whenComplete(() => _inFlight = null);
  }

  /// Re-runs a failed ensure. Never re-analyses a manifest that succeeded.
  Future<void> retry() {
    final preview = state.preview ?? _ensured;
    if (preview == null) return Future<void>.value();
    _ensured = null;
    return ensure(preview);
  }

  Future<void> _ensure(CanonicalPreviewRef preview) async {
    state = RealizedLookState(
      status: RealizedLookStatus.ensuring,
      preview: preview,
    );
    try {
      final session = await _resolveManifest(preview);
      if (!mounted) return;
      // Identity guard. A manifest describes one canonical preview and is not
      // evidence about any other, so a session that came back for a different
      // one is refused rather than displayed. Regenerating a preview is the
      // case this protects: the previous look's category set must never
      // silently become the new look's breakdown.
      if (session.canonicalPreviewId != preview.id) {
        _ensured = null;
        state = RealizedLookState(
          status: RealizedLookStatus.failed,
          preview: preview,
        );
        return;
      }
      _ensured = preview;
      // A kit-preview mismatch is a validation outcome, not a rendering
      // problem. It is surfaced rather than resolved by quietly dropping the
      // unbacked category, which would present an unreproducible look as valid.
      if (session.hasKitPreviewMismatch) {
        state = RealizedLookState(
          status: RealizedLookStatus.kitPreviewMismatch,
          preview: preview,
          session: session,
          retryable: false,
        );
        return;
      }
      if (!session.hasReusableManifest) {
        state = RealizedLookState(
          status: RealizedLookStatus.failed,
          preview: preview,
          session: session,
        );
        return;
      }
      state = RealizedLookState(
        status: RealizedLookStatus.ready,
        preview: preview,
        session: session,
      );
    } on TutorialFailure catch (failure) {
      if (!mounted) return;
      _ensured = null;
      state = RealizedLookState(
        status: RealizedLookStatus.failed,
        preview: preview,
        message: failure.message,
        retryable: failure.retryable,
      );
    } catch (_) {
      if (!mounted) return;
      _ensured = null;
      state = RealizedLookState(
        status: RealizedLookStatus.failed,
        preview: preview,
      );
    }
  }
}
