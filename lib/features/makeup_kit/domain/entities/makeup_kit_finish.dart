/// The full vocabulary of finish values available across My Makeup Kit
/// product categories.
///
/// Not every finish is valid for every [MakeupKitCategory] — see
/// `MakeupKitFinishCatalog` for the allowed per-category combinations.
enum MakeupKitFinish {
  matte('matte'),
  natural('natural'),
  dewy('dewy'),
  satin('satin'),
  radiant('radiant'),
  shimmer('shimmer'),
  metallic('metallic'),
  glitter('glitter'),
  cream('cream'),
  glossy('glossy');

  const MakeupKitFinish(this.code);

  final String code;

  static MakeupKitFinish? fromCode(String code) {
    for (final finish in values) {
      if (finish.code == code) return finish;
    }
    return null;
  }
}
