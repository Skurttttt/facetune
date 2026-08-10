import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../analysis/presentation/controllers/face_analysis_controller.dart';
import '../../../analysis/presentation/controllers/face_analysis_state.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/entities/selfie_source.dart';
import '../controllers/scan_controller.dart';
import '../controllers/scan_state.dart';

class ScanPage extends ConsumerWidget {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanControllerProvider);
    final controller = ref.read(scanControllerProvider.notifier);
    final analysisState = ref.watch(faceAnalysisControllerProvider);
    final selfie = state.selfie;
    ref.listen<FaceAnalysisState>(faceAnalysisControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.status != FaceAnalysisStatus.success &&
          next.status == FaceAnalysisStatus.success &&
          context.mounted) {
        context.push(AppConstants.analysisRoute);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('New scan')),
      body: SafeArea(
        child: PageFrame(
          child: ListView(
            children: [
              Text(
                selfie == null
                    ? 'Let’s find your best look.'
                    : 'Preview your selfie',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                selfie == null
                    ? 'Use a clear, front-facing photo in soft natural light.'
                    : 'Make sure your face is clear before continuing.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.taupe),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SelfieFrame(state: state),
              const SizedBox(height: AppSpacing.lg),
              const _GuidanceCard(),
              if (state.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                _ScanError(
                  message: state.errorMessage!,
                  canOpenSettings: state.canOpenSettings,
                  canRetryValidation: state.canRetryValidation,
                  onOpenSettings: controller.openSettings,
                  onRetryValidation: controller.validateForAnalysis,
                ),
              ],
              if (state.stage == ScanStage.readyForSecureValidation) ...[
                const SizedBox(height: AppSpacing.md),
                const AppCard(
                  color: AppColors.petal,
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: AppColors.rose),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Local checks passed. Your selfie is ready for secure face, lighting, sharpness, visibility, and framing checks.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (analysisState.message != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  color: AppColors.petal,
                  child: Text(analysisState.message!),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (selfie == null) ...[
                PrimaryButton(
                  label: _cameraLabel(state),
                  icon: Icons.camera_alt_outlined,
                  onPressed: state.isBusy ? null : controller.takePhoto,
                ),
                const SizedBox(height: AppSpacing.sm),
                SecondaryButton(
                  label: _galleryLabel(state),
                  icon: Icons.photo_library_outlined,
                  onPressed: state.isBusy ? null : controller.chooseFromGallery,
                ),
              ] else ...[
                PrimaryButton(
                  label: _primaryLabel(state, analysisState),
                  icon: Icons.arrow_forward_rounded,
                  onPressed: state.isBusy || analysisState.isBusy
                      ? null
                      : state.stage == ScanStage.readyForSecureValidation
                      ? () => ref
                            .read(faceAnalysisControllerProvider.notifier)
                            .analyze(
                              selfie: selfie,
                              localValidation: state.localValidation!,
                            )
                      : controller.validateForAnalysis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Retake',
                        icon: Icons.camera_alt_outlined,
                        onPressed: state.isBusy || analysisState.isBusy
                            ? null
                            : controller.takePhoto,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: SecondaryButton(
                        label: 'Reselect',
                        icon: Icons.photo_library_outlined,
                        onPressed: state.isBusy || analysisState.isBusy
                            ? null
                            : controller.chooseFromGallery,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _cameraLabel(ScanState state) {
    return state.isBusy && state.activeSource == SelfieSource.camera
        ? 'Preparing selfie…'
        : 'Take a photo';
  }

  String _galleryLabel(ScanState state) {
    return state.isBusy && state.activeSource == SelfieSource.gallery
        ? 'Preparing selfie…'
        : 'Choose from gallery';
  }

  String _primaryLabel(ScanState scanState, FaceAnalysisState analysisState) {
    if (analysisState.status == FaceAnalysisStatus.uploading) {
      return 'Uploading securely…';
    }
    if (analysisState.status == FaceAnalysisStatus.secureProcessing) {
      return 'Analyzing securely…';
    }
    return switch (scanState.stage) {
      ScanStage.validatingLocal => 'Validating image…',
      ScanStage.readyForSecureValidation => 'Analyze selfie',
      _ => 'Validate selfie',
    };
  }
}

class _SelfieFrame extends StatelessWidget {
  const _SelfieFrame({required this.state});

  final ScanState state;

  @override
  Widget build(BuildContext context) {
    final selfie = state.selfie;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: Container(
        height: 340,
        decoration: BoxDecoration(
          color: AppColors.petal,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: AppColors.blush, width: 2),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (selfie == null)
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.face_rounded, size: 108, color: AppColors.rose),
                  SizedBox(height: AppSpacing.md),
                  Text('Center your face in the frame'),
                ],
              )
            else
              Image.file(
                File(selfie.originalPath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Text(
                    'Preview unavailable. Please choose another image.',
                  ),
                ),
              ),
            if (state.isBusy)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.32),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard();

  @override
  Widget build(BuildContext context) => const AppCard(
    child: Column(
      children: [
        _TipRow(Icons.person_outline_rounded, 'One person only'),
        _TipRow(Icons.face_outlined, 'Face fully visible'),
        _TipRow(Icons.light_mode_outlined, 'Good, even lighting'),
        _TipRow(Icons.blur_off_rounded, 'Avoid heavy blur'),
        _TipRow(Icons.screen_rotation_outlined, 'Avoid extreme angles'),
      ],
    ),
  );
}

class _ScanError extends StatelessWidget {
  const _ScanError({
    required this.message,
    required this.canOpenSettings,
    required this.canRetryValidation,
    required this.onOpenSettings,
    required this.onRetryValidation,
  });

  final String message;
  final bool canOpenSettings;
  final bool canRetryValidation;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetryValidation;

  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.petal,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        if (canOpenSettings) ...[
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Open Settings'),
          ),
        ],
        if (canRetryValidation) ...[
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: onRetryValidation,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry validation'),
          ),
        ],
      ],
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
