enum SelfieFailureType {
  permissionDenied,
  permissionPermanentlyDenied,
  unsupportedType,
  fileTooLarge,
  unreadableFile,
  preparationFailed,
}

class SelfieFailure implements Exception {
  const SelfieFailure(this.type, this.message);

  final SelfieFailureType type;
  final String message;

  bool get canOpenSettings =>
      type == SelfieFailureType.permissionPermanentlyDenied;
}
