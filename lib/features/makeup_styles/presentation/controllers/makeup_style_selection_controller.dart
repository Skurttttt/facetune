import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/makeup_style.dart';
import 'makeup_style_selection_state.dart';

final makeupStyleSelectionControllerProvider =
    StateNotifierProvider<
      MakeupStyleSelectionController,
      MakeupStyleSelectionState
    >((ref) => MakeupStyleSelectionController());

class MakeupStyleSelectionController
    extends StateNotifier<MakeupStyleSelectionState> {
  MakeupStyleSelectionController() : super(const MakeupStyleSelectionState());

  void select(MakeupStyle style) {
    state = MakeupStyleSelectionState(selectedStyle: style);
  }

  void confirm() {
    if (state.selectedStyle == null) return;
    state = MakeupStyleSelectionState(
      selectedStyle: state.selectedStyle,
      isConfirmed: true,
    );
  }

  void clear() => state = const MakeupStyleSelectionState();

  void restore(MakeupStyle style) {
    state = MakeupStyleSelectionState(selectedStyle: style, isConfirmed: true);
  }
}
