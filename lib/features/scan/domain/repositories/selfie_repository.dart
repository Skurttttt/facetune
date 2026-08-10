import '../entities/prepared_selfie.dart';
import '../entities/selfie_source.dart';

abstract interface class SelfieRepository {
  Future<PreparedSelfie?> acquire(SelfieSource source);

  Future<bool> openPermissionSettings();

  Future<void> discard(PreparedSelfie selfie);
}
