import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../domain/entities/foundation_depth.dart';
import '../../domain/entities/foundation_undertone.dart';
import '../utils/makeup_kit_display.dart';
import 'makeup_kit_choice_chip_group.dart';

/// Foundation-only Depth and Undertone selectors.
///
/// Only ever shown for the Foundation category — the caller is responsible
/// for not mounting this widget for any other category, matching guide
/// §9's "do not force foundation-only fields onto unrelated categories".
class MakeupKitFoundationAttributesSelector extends StatelessWidget {
  const MakeupKitFoundationAttributesSelector({
    required this.selectedDepth,
    required this.selectedUndertone,
    required this.onDepthSelected,
    required this.onUndertoneSelected,
    super.key,
  });

  final FoundationDepth? selectedDepth;
  final FoundationUndertone? selectedUndertone;
  final ValueChanged<FoundationDepth> onDepthSelected;
  final ValueChanged<FoundationUndertone> onUndertoneSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Depth', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: AppSpacing.xs),
      MakeupKitChoiceChipGroup<FoundationDepth>(
        options: FoundationDepth.values,
        selected: selectedDepth,
        labelOf: (depth) => depth.label,
        onSelected: onDepthSelected,
        showCheckmark: false,
      ),
      // Between the two groups; the chips' tap padding adds a few more points.
      const SizedBox(height: AppSpacing.sm),
      Text('Undertone', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: AppSpacing.xs),
      MakeupKitChoiceChipGroup<FoundationUndertone>(
        options: FoundationUndertone.values,
        selected: selectedUndertone,
        labelOf: (undertone) => undertone.label,
        onSelected: onUndertoneSelected,
        showCheckmark: false,
      ),
    ],
  );
}
