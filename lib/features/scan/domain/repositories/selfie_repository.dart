import '../entities/prepared_selfie.dart';
import '../entities/selfie_source.dart';

abstract interface class SelfieRepository {
  Future<PreparedSelfie?> acquire(SelfieSource source);

  /// Prepares a still that was already captured, at [path].
  ///
  /// The in-app camera produces a file directly rather than going through the
  /// OS picker, but everything downstream of that difference must stay
  /// identical: the same file validation, the same compression, the same
  /// temporary staging, the same [PreparedSelfie]. Reusing one preparation path
  /// is what keeps the live-camera still and the gallery image indistinguishable
  /// to the secure pipeline.
  Future<PreparedSelfie> prepareCaptured(String path);

  Future<bool> openPermissionSettings();

  Future<void> discard(PreparedSelfie selfie);
}
