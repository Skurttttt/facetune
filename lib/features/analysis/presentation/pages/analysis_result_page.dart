import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/entities/face_analysis.dart';
import '../controllers/face_analysis_controller.dart';

class AnalysisResultPage extends ConsumerWidget {
  const AnalysisResultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(faceAnalysisControllerProvider).analysis;
    return Scaffold(
      appBar: const FaceTuneTopBar(title: 'Your beauty profile'),
      body: SafeArea(
        child: PageFrame(
          child: analysis == null
              ? StatusState.error(
                  title: 'Analysis unavailable',
                  message: 'Return to Scan and analyze a validated selfie.',
                  actionLabel: 'Return to scan',
                  onAction: () => context.go(AppConstants.scanRoute),
                )
              : _AnalysisContent(analysis: analysis),
        ),
      ),
    );
  }
}

class _AnalysisContent extends StatelessWidget {
  const _AnalysisContent({required this.analysis});

  final FaceAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final attributes = <String, ({String value, double confidence})>{
      'Face shape': (
        value: _label(analysis.attributes.faceShape.name),
        confidence: analysis.confidence.faceShape,
      ),
      'Skin tone': (
        value: _label(analysis.attributes.skinTone.name),
        confidence: analysis.confidence.skinTone,
      ),
      'Undertone': (
        value: _label(analysis.attributes.undertone.name),
        confidence: analysis.confidence.undertone,
      ),
      'Eye shape': (
        value: _label(analysis.attributes.eyeShape.name),
        confidence: analysis.confidence.eyeShape,
      ),
      'Lip shape': (
        value: _label(analysis.attributes.lipShape.name),
        confidence: analysis.confidence.lipShape,
      ),
      'Hair color': (
        value: _label(analysis.attributes.hairColor.name),
        confidence: analysis.confidence.hairColor,
      ),
      'Eye color': (
        value: _label(analysis.attributes.eyeColor.name),
        confidence: analysis.confidence.eyeColor,
      ),
    };
    return ListView(
      children: [
        const SizedBox(height: AppSpacing.md),
        // The result of the secure checks, stated as the success it is. The
        // confidence figures below are the model's own, unchanged — this screen
        // reports state, it does not invent a step or a percentage.
        const AppNotice(
          tone: AppTone.success,
          title: 'Analysis complete',
          message:
              'Your selfie passed secure visibility, lighting, sharpness, and '
              'framing checks.',
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader('Detected attributes'),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            children: [
              for (final (index, item) in attributes.entries.indexed) ...[
                if (index > 0) const Divider(height: AppSpacing.xxs),
                _AttributeRow(
                  label: item.key,
                  value: item.value.value,
                  confidence: item.value.confidence,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Choose a makeup style',
          onPressed: () => context.push(AppConstants.stylesRoute),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  static String _label(String value) {
    final words = value.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }
}

/// One detected attribute, its value, and the model's confidence in it.
///
/// The confidence figure is reported exactly as the analysis supplied it. It is
/// the only number on this screen and it is not derived, rounded up, or
/// presented as progress.
class _AttributeRow extends StatelessWidget {
  const _AttributeRow({
    required this.label,
    required this.value,
    required this.confidence,
  });

  final String label;
  final String value;
  final double confidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelText = Text(label, style: theme.textTheme.bodyMedium);
    final valueBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '${(confidence * 100).round()}% confidence',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.muted(context),
          ),
        ),
      ],
    );

    return Semantics(
      container: true,
      excludeSemantics: true,
      // Read as one sentence. Split across three nodes a screen reader
      // announces "Face shape", "Oval", "92% confidence" as unrelated
      // fragments.
      label: '$label: $value, ${(confidence * 100).round()} percent confidence',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: MediaQuery.textScalerOf(context).scale(14) > 20
            // Seven attribute names sit beside a value and a confidence line.
            // Past this scale there is no width left for two columns, so they
            // stack rather than wrapping into slivers.
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  labelText,
                  const SizedBox(height: AppSpacing.xxs),
                  valueBlock,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: labelText),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(child: valueBlock),
                ],
              ),
      ),
    );
  }
}
