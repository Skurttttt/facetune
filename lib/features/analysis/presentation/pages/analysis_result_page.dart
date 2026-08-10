import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/entities/face_analysis.dart';
import '../controllers/face_analysis_controller.dart';

class AnalysisResultPage extends ConsumerWidget {
  const AnalysisResultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(faceAnalysisControllerProvider).analysis;
    return Scaffold(
      appBar: AppBar(title: const Text('Your beauty profile')),
      body: SafeArea(
        child: PageFrame(
          child: analysis == null
              ? const StatusState(
                  title: 'Analysis unavailable',
                  message: 'Return to Scan and analyze a validated selfie.',
                  icon: Icons.error_outline_rounded,
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
        Row(
          children: [
            const Icon(Icons.verified_rounded, color: AppColors.success),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Analysis complete',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Your selfie passed secure visibility, lighting, sharpness, and framing checks.',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            children: attributes.entries
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(child: Text(item.key)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              item.value.value,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${(item.value.confidence * 100).round()}% confidence',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Choose a makeup style',
          onPressed: () => context.push(AppConstants.stylesRoute),
        ),
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
