import 'package:flutter/material.dart';

import '../../../../shared/widgets/surfaces/app_card.dart';
import '../../../../theme/app_tokens.dart';
import '../../../analysis/domain/entities/face_analysis.dart';
import '../utils/result_formatters.dart';

class BeautyProfileCard extends StatelessWidget {
  const BeautyProfileCard({required this.analysis, super.key});

  final FaceAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final attributes = <({String label, String value, double confidence})>[
      (
        label: 'Face shape',
        value: ResultFormatters.label(analysis.attributes.faceShape.name),
        confidence: analysis.confidence.faceShape,
      ),
      (
        label: 'Skin tone',
        value: ResultFormatters.label(analysis.attributes.skinTone.name),
        confidence: analysis.confidence.skinTone,
      ),
      (
        label: 'Undertone',
        value: ResultFormatters.label(analysis.attributes.undertone.name),
        confidence: analysis.confidence.undertone,
      ),
      (
        label: 'Eye shape',
        value: ResultFormatters.label(analysis.attributes.eyeShape.name),
        confidence: analysis.confidence.eyeShape,
      ),
      (
        label: 'Lip shape',
        value: ResultFormatters.label(analysis.attributes.lipShape.name),
        confidence: analysis.confidence.lipShape,
      ),
      (
        label: 'Hair color',
        value: ResultFormatters.label(analysis.attributes.hairColor.name),
        confidence: analysis.confidence.hairColor,
      ),
      (
        label: 'Eye color',
        value: ResultFormatters.label(analysis.attributes.eyeColor.name),
        confidence: analysis.confidence.eyeColor,
      ),
    ];
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        children: [
          for (var index = 0; index < attributes.length; index++) ...[
            _ProfileAttributeRow(attribute: attributes[index]),
            if (index != attributes.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _ProfileAttributeRow extends StatelessWidget {
  const _ProfileAttributeRow({required this.attribute});

  final ({String label, String value, double confidence}) attribute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confidence = '${(attribute.confidence * 100).round()}%';
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '${attribute.label}, ${attribute.value}, $confidence confidence',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackValue =
              constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(14) > 19;
          final valueAndConfidence = Row(
            mainAxisSize: stackValue ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (stackValue)
                Expanded(
                  child: Text(
                    attribute.value,
                    style: theme.textTheme.titleSmall,
                  ),
                )
              else
                Text(attribute.value, style: theme.textTheme.titleSmall),
              const SizedBox(width: AppSpacing.sm),
              Text(
                confidence,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.muted(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: stackValue
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attribute.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.muted(context),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      valueAndConfidence,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          attribute.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.muted(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      valueAndConfidence,
                    ],
                  ),
          );
        },
      ),
    );
  }
}
