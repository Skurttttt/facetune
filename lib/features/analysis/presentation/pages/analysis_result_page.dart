import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../shared/widgets/app_ui.dart';

class AnalysisResultPage extends StatelessWidget {
  const AnalysisResultPage({super.key});

  static const attributes = {
    'Face shape': 'Oval',
    'Skin tone': 'Medium',
    'Undertone': 'Warm',
    'Eye shape': 'Almond',
    'Lip shape': 'Full',
    'Eye color': 'Deep brown',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your beauty profile')),
    body: SafeArea(
      child: PageFrame(
        child: ListView(
          children: [
            const BeautyImage(height: 290),
            const SizedBox(height: AppSpacing.lg),
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
              'Your warm undertone and balanced proportions pair beautifully with luminous, softly sculpted color.',
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
                            Text(
                              item.value,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
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
              label: 'Create my Soft Glam look',
              onPressed: () => context.push(AppConstants.previewRoute),
            ),
          ],
        ),
      ),
    ),
  );
}
