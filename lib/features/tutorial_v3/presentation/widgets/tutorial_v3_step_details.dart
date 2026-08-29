import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../../makeup_kit/presentation/utils/makeup_kit_display.dart';
import '../../domain/entities/tutorial_v3_product_snapshot.dart';
import '../../domain/entities/tutorial_v3_step_instructions.dart';

/// The labelled instruction blocks for one guideline step.
///
/// **Every word here is copied from the persisted Step Spec.** Nothing is
/// generated, inferred, translated or reworded at display time, and no text is
/// ever read out of an image. The labels below are the only strings this file
/// contributes; the values are all `instructions.*`.
///
/// Optional fields are omitted rather than shown empty, so a step that the
/// planner had nothing to say about does not display a blank heading.
class TutorialV3StepDetails extends StatelessWidget {
  const TutorialV3StepDetails({required this.instructions, super.key});

  final TutorialV3StepInstructions instructions;

  @override
  Widget build(BuildContext context) {
    final product = instructions.product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (product != null) ...[
          _Block(
            label: 'APPLY',
            child: _Product(product: product),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        _Block(label: 'WHERE', value: instructions.whereToApply),
        const SizedBox(height: AppSpacing.md),
        _Block(label: 'DIRECTION', value: instructions.direction),
        const SizedBox(height: AppSpacing.md),
        _Block(label: 'TECHNIQUE', value: instructions.technique),
        if (instructions.coverage != null) ...[
          const SizedBox(height: AppSpacing.md),
          _Block(label: 'COVERAGE', value: instructions.coverage!),
        ],
        if (instructions.intensity != null) ...[
          const SizedBox(height: AppSpacing.md),
          _Block(label: 'INTENSITY', value: instructions.intensity!),
        ],
        if (instructions.amount != null) ...[
          const SizedBox(height: AppSpacing.md),
          _Block(label: 'HOW MUCH', value: instructions.amount!),
        ],
        if (instructions.toolSuggestion != null) ...[
          const SizedBox(height: AppSpacing.md),
          _Block(label: 'TOOL', value: instructions.toolSuggestion!),
        ],
        const SizedBox(height: AppSpacing.md),
        _Block(
          label: 'WHY THIS PLACEMENT',
          value: instructions.whyThisPlacement,
        ),
        const SizedBox(height: AppSpacing.md),
        _Block(
          label: 'HOW THIS BUILDS THE LOOK',
          value: instructions.howThisBuildsTheLook,
        ),
        if (instructions.tip != null) ...[
          const SizedBox(height: AppSpacing.md),
          _Block(label: 'TIP', value: instructions.tip!),
        ],
        if (instructions.avoid != null) ...[
          const SizedBox(height: AppSpacing.md),
          _Block(label: 'AVOID', value: instructions.avoid!),
        ],
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.label, this.value, this.child});

  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: AppColors.taupe,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          child ?? Text(value!, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

/// The product a step teaches, rendered from its persisted snapshot.
///
/// The snapshot was captured when the plan was built, so a Kit product that has
/// since been edited or deleted still shows the shade the tutorial was written
/// for rather than silently changing under the user.
class _Product extends StatelessWidget {
  const _Product({required this.product});

  final TutorialV3ProductSnapshot product;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (product.productName != null) product.productName!,
      if (product.shadeName != null) product.shadeName!,
      if (product.finish != null) product.finish!.label,
    ];
    final description = parts.isEmpty
        ? product.category.label
        : parts.join(' · ');
    final swatch = product.color;

    return Row(
      children: [
        if (swatch != null) ...[
          Container(
            width: AppIconSizes.sm,
            height: AppIconSizes.sm,
            decoration: BoxDecoration(
              color: swatch.toColor(),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.sand),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        Expanded(
          child: Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        if (product.isOwnedProduct)
          // Kit steps teach something the user actually owns; standard steps
          // recommend a shade they do not. Saying which is the difference
          // between "use yours" and "look for one like this".
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: Text(
              'From your kit',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
      ],
    );
  }
}
