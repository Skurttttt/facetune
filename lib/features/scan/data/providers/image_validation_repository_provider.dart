import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/image_validation_repository.dart';
import '../repositories/flutter_image_validation_repository.dart';

final imageValidationRepositoryProvider = Provider<ImageValidationRepository>(
  (ref) => const FlutterImageValidationRepository(),
);
