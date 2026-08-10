import '../../domain/entities/makeup_style.dart';

class MakeupStyleSelectionState {
  const MakeupStyleSelectionState({
    this.selectedStyle,
    this.isConfirmed = false,
  });

  final MakeupStyle? selectedStyle;
  final bool isConfirmed;
}
