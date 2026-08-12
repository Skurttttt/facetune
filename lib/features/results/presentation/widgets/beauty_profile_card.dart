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
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: attributes
            .map(
              (attribute) => Semantics(
                label:
                    '${attribute.label}, ${attribute.value}, ${(attribute.confidence * 100).round()} percent confidence',
                child: ExcludeSemantics(
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 130),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.petal,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          attribute.label,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.onAccent(AppColors.petal),
                              ),
                        ),
                        Text(
                          attribute.value,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: AppColors.onAccent(AppColors.petal),
                              ),
                        ),
                        Text(
                          '${(attribute.confidence * 100).round()}% confidence',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.onAccent(AppColors.petal),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
