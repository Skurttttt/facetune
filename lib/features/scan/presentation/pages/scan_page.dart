import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../shared/widgets/app_ui.dart';

class ScanPage extends StatelessWidget {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New scan')),
    body: SafeArea(
      child: PageFrame(
        child: ListView(
          children: [
            Text(
              'Letâ€™s find your best look.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Use a clear, front-facing photo in soft natural light.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.taupe),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              height: 340,
              decoration: BoxDecoration(
                color: AppColors.petal,
                borderRadius: BorderRadius.circular(AppRadii.xl),
                border: Border.all(color: AppColors.blush, width: 2),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.face_rounded, size: 108, color: AppColors.rose),
                  SizedBox(height: AppSpacing.md),
                  Text('Center your face in the frame'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _TipRow(Icons.light_mode_outlined, 'Even, soft lighting'),
            const _TipRow(Icons.face_outlined, 'One face, fully visible'),
            const _TipRow(Icons.blur_off_rounded, 'Sharp and unfiltered'),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Take a photo',
              icon: Icons.camera_alt_outlined,
              onPressed: () => context.push(AppConstants.stylesRoute),
            ),
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: 'Choose from gallery',
              icon: Icons.photo_library_outlined,
              onPressed: () => context.push(AppConstants.stylesRoute),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TipRow extends StatelessWidget {
  const _TipRow(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, color: AppColors.rose, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Text(label),
      ],
    ),
  );
}
