import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/entities/tutorial_instruction.dart';
import '../../domain/entities/tutorial_step_category.dart';

/// Written guidance for one tutorial step: Color, Finish, Placement,
/// Direction, Intensity, Technique, and an optional Tip — the field set
/// FACETUNE_STEP_BY_STEP_TUTORIAL_GUIDE.md §8/§18 specify. Fields the
/// instruction does not carry (e.g. no [TutorialInstruction.direction] for
/// a foundation step) are simply omitted rather than shown blank.
class TutorialInstructionCard extends StatelessWidget {
  const TutorialInstructionCard({required this.instruction, super.key});

  final TutorialInstruction instruction;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (instruction.hex != null) ...[
              _ColorSwatch(hex: instruction.hex!),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                instruction.productName ??
                    instruction.colorName ??
                    _categoryLabel(instruction.category),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (instruction.colorName != null)
          _Detail(
            label: 'Color',
            value: instruction.hex == null
                ? instruction.colorName!
                : '${instruction.colorName} · ${instruction.hex}',
          ),
        if (instruction.finish != null)
          _Detail(label: 'Finish', value: instruction.finish!),
        _Detail(label: 'Placement', value: instruction.placement),
        if (instruction.direction != null)
          _Detail(label: 'Direction', value: instruction.direction!),
        _Detail(label: 'Intensity', value: instruction.intensity),
        _Detail(label: 'Technique', value: instruction.technique),
        if (instruction.tip != null)
          _Detail(label: 'Tip', value: instruction.tip!),
      ],
    ),
  );

  static String _categoryLabel(TutorialStepCategory category) {
    final words = category.code.replaceAll('_', ' ');
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.hex});

  final String hex;

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    ),
  );
}
