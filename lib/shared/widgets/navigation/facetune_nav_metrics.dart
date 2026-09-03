import '../../../theme/app_tokens.dart';

/// Geometry shared by FaceTune's route-navigation presentation.
///
/// Component constants rather than entries in `app_tokens.dart`, for the same
/// reason `AppButtonMetrics` is: these are the dimensions of one component
/// family, not a scale anything else should be reading. What matters is that
/// they live in exactly one place — the drift this phase set out to remove was
/// every screen deciding its own back-button size and its own title inset.
abstract final class FaceTuneNavMetrics {
  /// Minimum touch target for the back control.
  ///
  /// 44 is the accessibility floor, and the circle is drawn at the full target
  /// rather than centred inside a larger invisible one: a 44pt ring reads as a
  /// deliberate control, and a smaller ring with padding around it reads as a
  /// small icon that happens to be tappable.
  static const touchTarget = 44.0;

  /// Chevron size inside [touchTarget].
  static const iconSize = 21.0;

  /// Width of the app bar's leading slot: the gutter, then the control.
  ///
  /// This is what aligns the back button's left edge with the page content
  /// below it. `AppBar`'s default leading slot is 56 wide with the glyph
  /// optically centred, which lands a few points inside the gutter and is why
  /// the default control never looked like it belonged to the page.
  static const leadingWidth = AppSpacing.gutter + touchTarget;

  /// Gap between the back control and a title.
  static const titleSpacing = AppSpacing.sm;

  /// Trailing padding after the last action.
  ///
  /// A standard 48-wide `IconButton` centres its 24pt glyph, so 8 here puts the
  /// glyph's optical edge on [AppSpacing.gutter] — the same inset as the back
  /// chevron on the other side.
  static const trailingInset = AppSpacing.xs;
}
