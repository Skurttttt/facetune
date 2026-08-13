import 'package:flutter/material.dart';

import '../../domain/entities/foundation_depth.dart';
import '../../domain/entities/foundation_undertone.dart';
import '../../domain/entities/makeup_kit_category.dart';
import '../../domain/entities/makeup_kit_finish.dart';
import '../../domain/value_objects/normalized_hex_color.dart';

/// Presentation-only display metadata for [MakeupKitCategory].
///
/// Deliberately kept out of the domain layer: MK-1 established
/// [MakeupKitCategory] as a stable identifier only, with display labels
/// left for whichever phase first needs them (this one).
extension MakeupKitCategoryDisplay on MakeupKitCategory {
  String get label => switch (this) {
    MakeupKitCategory.foundation => 'Foundation',
    MakeupKitCategory.concealer => 'Concealer',
    MakeupKitCategory.blush => 'Blush',
    MakeupKitCategory.highlighter => 'Highlighter',
    MakeupKitCategory.eyeshadow => 'Eyeshadow',
    MakeupKitCategory.lipstick => 'Lipstick',
    MakeupKitCategory.lipGloss => 'Lip Gloss',
    MakeupKitCategory.contourBronzer => 'Contour/Bronzer',
    MakeupKitCategory.eyebrow => 'Eyebrow',
    MakeupKitCategory.eyeliner => 'Eyeliner',
  };

  IconData get icon => switch (this) {
    MakeupKitCategory.foundation => Icons.face_outlined,
    MakeupKitCategory.concealer => Icons.brush_outlined,
    MakeupKitCategory.blush => Icons.circle_outlined,
    MakeupKitCategory.highlighter => Icons.auto_awesome_outlined,
    MakeupKitCategory.eyeshadow => Icons.visibility_outlined,
    MakeupKitCategory.lipstick => Icons.colorize_outlined,
    MakeupKitCategory.lipGloss => Icons.water_drop_outlined,
    MakeupKitCategory.contourBronzer => Icons.blur_on_outlined,
    MakeupKitCategory.eyebrow => Icons.horizontal_rule_rounded,
    MakeupKitCategory.eyeliner => Icons.edit_outlined,
  };
}

extension MakeupKitFinishDisplay on MakeupKitFinish {
  String get label => switch (this) {
    MakeupKitFinish.matte => 'Matte',
    MakeupKitFinish.natural => 'Natural',
    MakeupKitFinish.dewy => 'Dewy',
    MakeupKitFinish.satin => 'Satin',
    MakeupKitFinish.radiant => 'Radiant',
    MakeupKitFinish.shimmer => 'Shimmer',
    MakeupKitFinish.metallic => 'Metallic',
    MakeupKitFinish.glitter => 'Glitter',
    MakeupKitFinish.cream => 'Cream',
    MakeupKitFinish.glossy => 'Glossy',
  };
}

extension FoundationDepthDisplay on FoundationDepth {
  String get label => switch (this) {
    FoundationDepth.fair => 'Fair',
    FoundationDepth.light => 'Light',
    FoundationDepth.medium => 'Medium',
    FoundationDepth.tan => 'Tan',
    FoundationDepth.deep => 'Deep',
  };
}

extension FoundationUndertoneDisplay on FoundationUndertone {
  String get label => switch (this) {
    FoundationUndertone.cool => 'Cool',
    FoundationUndertone.neutral => 'Neutral',
    FoundationUndertone.warm => 'Warm',
  };
}

/// Converts a validated [NormalizedHexColor] to a Flutter [Color].
///
/// Safe by construction: [NormalizedHexColor] only ever holds a value
/// matching `^#[0-9A-F]{6}$`, so this never needs the defensive parsing the
/// three existing ad-hoc hex-to-Color call sites in `results`/
/// `recommendation` use for untyped strings.
extension NormalizedHexColorDisplay on NormalizedHexColor {
  Color toColor() => Color(int.parse('FF${value.substring(1)}', radix: 16));
}
