import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/makeup_recommendation_mode.dart';

final makeupRecommendationModeControllerProvider =
    StateNotifierProvider<
      MakeupRecommendationModeController,
      MakeupRecommendationMode?
    >((ref) => MakeupRecommendationModeController());

class MakeupRecommendationModeController
    extends StateNotifier<MakeupRecommendationMode?> {
  MakeupRecommendationModeController() : super(null);

  void select(MakeupRecommendationMode mode) => state = mode;

  void clear() => state = null;
}
