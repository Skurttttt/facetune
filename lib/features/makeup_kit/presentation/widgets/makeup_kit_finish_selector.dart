import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../domain/entities/makeup_kit_finish.dart';
import '../utils/makeup_kit_display.dart';
import 'makeup_kit_choice_chip_group.dart';

/// A single-select chip row limited to the finishes valid for the currently
/// selected category (the caller passes the already-filtered [options] —
/// see `MakeupKitFinishCatalog.allowedFinishes`).
class MakeupKitFinishSelector extends StatelessWidget {
  const MakeupKitFinishSelector({
    required this.options,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<MakeupKitFinish> options;
  final MakeupKitFinish? selected;
  final ValueChanged<MakeupKitFinish> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Finish', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: AppSpacing.xs),
      MakeupKitChoiceChipGroup<MakeupKitFinish>(
        options: options,
        selected: selected,
        labelOf: (finish) => finish.label,
        onSelected: onSelected,
      ),
    ],
  );
}
