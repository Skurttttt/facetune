import '../entities/local_image_validation.dart';
import '../entities/prepared_selfie.dart';

abstract interface class ImageValidationRepository {
  Future<LocalImageValidation> validateLocal(PreparedSelfie selfie);
}
