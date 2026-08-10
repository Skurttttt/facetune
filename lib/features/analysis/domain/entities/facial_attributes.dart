enum FaceShape { oval, round, square, heart, oblong, diamond, triangle }

enum SkinTone { veryLight, light, medium, tan, deep, veryDeep }

enum Undertone { warm, cool, neutral, olive }

enum EyeShape {
  almond,
  round,
  hooded,
  monolid,
  upturned,
  downturned,
  deepSet,
  protruding,
}

enum LipShape { thin, medium, full, heartShaped, wide, round }

enum HairColor {
  black,
  darkBrown,
  brown,
  lightBrown,
  blonde,
  red,
  gray,
  white,
  other,
}

enum EyeColor { darkBrown, brown, hazel, amber, green, blue, gray, other }

class FacialAttributes {
  const FacialAttributes({
    required this.faceShape,
    required this.skinTone,
    required this.undertone,
    required this.eyeShape,
    required this.lipShape,
    required this.hairColor,
    required this.eyeColor,
  });

  final FaceShape faceShape;
  final SkinTone skinTone;
  final Undertone undertone;
  final EyeShape eyeShape;
  final LipShape lipShape;
  final HairColor hairColor;
  final EyeColor eyeColor;
}
