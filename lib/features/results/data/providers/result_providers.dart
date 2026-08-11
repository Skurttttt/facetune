import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/result_share_service.dart';
import '../services/native_result_share_service.dart';

final resultShareServiceProvider = Provider<ResultShareService>(
  (ref) => const NativeResultShareService(),
);
