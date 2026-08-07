import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/app_router.dart';
import '../../features/settings/presentation/controllers/theme_mode_controller.dart';
import '../config/app_config.dart';

final appDependenciesProvider = Provider<void>((ref) {
  ref.watch(appConfigProvider);
  ref.watch(themeModeProvider);
  ref.watch(appRouterProvider);
});
