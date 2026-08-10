class SecureImageValidation {
  const SecureImageValidation({
    required this.faceCount,
    required this.lightingAcceptable,
    required this.sharpnessAcceptable,
    required this.faceVisible,
    required this.framingAcceptable,
  });

  final int faceCount;
  final bool lightingAcceptable;
  final bool sharpnessAcceptable;
  final bool faceVisible;
  final bool framingAcceptable;
}
