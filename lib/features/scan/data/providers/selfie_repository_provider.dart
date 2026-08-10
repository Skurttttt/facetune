import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/selfie_repository.dart';
import '../repositories/device_selfie_repository.dart';

final selfieRepositoryProvider = Provider<SelfieRepository>(
  (ref) => DeviceSelfieRepository(),
);
