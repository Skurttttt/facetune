import 'package:flutter/painting.dart';

import '../../domain/entities/tutorial_category.dart';

/// Where the full-screen viewer should start looking, per category.
///
/// A presentation hint and nothing more. It carries no face geometry: there are
/// no landmarks, no detection, and no per-photo coordinates. It is the same
/// coarse assumption a portrait crop already makes — eyes sit in the upper
/// third of a framed face, lips in the lower third — applied to an image the
/// app already has. Nothing here is persisted, sent to a model, or used to
/// place a mark.
///
/// The point is small-feature usability. A wing of eyeliner occupies a few
/// dozen pixels of a 3:4 portrait on a 393pt-wide phone, and asking the user to
/// pinch their way to it every time is the actual problem this solves. A
/// complexion category has no small feature, so it opens unzoomed.
///
/// Two rules keep it honest, and both are enforced by the viewer rather than
/// trusted here:
///
///  * the whole image stays reachable — [scale] is a starting point, never a
///    crop, and the viewer can always be panned and zoomed back out to the full
///    frame, so no facial context is ever removed;
///  * [scale] stays modest. Opening at 4x would look decisive and be wrong on
///    any face framed differently from the assumption.
enum TutorialImageFocus {
  /// The whole face, unzoomed. What a complexion step needs.
  wholeFace(1, Alignment.center),

  /// The eye region, in the upper third of a portrait frame.
  eyes(1.7, Alignment(0, -0.45)),

  /// The cheeks, a little above centre.
  midFace(1.35, Alignment(0, -0.1)),

  /// The mouth, in the lower third.
  mouth(1.7, Alignment(0, 0.4));

  const TutorialImageFocus(this.scale, this.alignment);

  /// The initial zoom the viewer opens at. 1 means the whole image.
  final double scale;

  /// The point of the image the initial zoom is centred on.
  final Alignment alignment;

  /// Whether this focus actually zooms, rather than showing the whole frame.
  bool get isZoomed => scale > 1;

  /// The focus for [category].
  ///
  /// Total over the vocabulary and written as an exhaustive switch, so adding a
  /// tenth category is a compile error here rather than a silent fall-through
  /// to `wholeFace`.
  ///
  /// Highlighter is deliberately [wholeFace] despite being a small-feature
  /// category: its points are spread across the brow bone, the nose, the
  /// cheekbone and the Cupid's bow, so any single zoom would hide most of them.
  /// Eyebrows share the eye framing because a brow sits inside it.
  static TutorialImageFocus forCategory(TutorialCategory category) =>
      switch (category) {
        TutorialCategory.foundation ||
        TutorialCategory.concealer ||
        TutorialCategory.contourBronzer ||
        TutorialCategory.highlighter => wholeFace,
        TutorialCategory.blush => midFace,
        TutorialCategory.eyebrows ||
        TutorialCategory.eyeshadow ||
        TutorialCategory.eyeliner => eyes,
        TutorialCategory.lips => mouth,
      };
}
