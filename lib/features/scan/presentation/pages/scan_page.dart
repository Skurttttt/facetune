import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';
import '../../../analysis/presentation/controllers/face_analysis_controller.dart';
import '../../../analysis/presentation/controllers/face_analysis_state.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
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
    final isBusy = state.isBusy || analysisState.isBusy;
    // Described, never quantified: nothing here knows what fraction of an
    // upload or a model call has elapsed, so nothing claims to.
    final progressLabel = switch (state.stage) {
      ScanStage.acquiring => 'Opening your photos…',
      ScanStage.validatingLocal => 'Checking photo…',
      _ => analysisState.isBusy ? 'Analyzing your features…' : null,
    };
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
      appBar: FaceTuneTopBar(
        title: 'New scan',
        actions: [
          if (selfie != null || analysisState.status != FaceAnalysisStatus.idle)
            IconButton(
              tooltip: 'Start over',
              onPressed: isBusy ? null : () => _beginNewScan(ref),
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: PageFrame(
          child: ListView(
            children: [
              Text(
                selfie == null
                    ? "Let's find your best look."
                    : 'Preview your selfie',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                selfie == null
                    ? 'Use a clear, front-facing photo in soft natural light.'
                    : 'Make sure your face is clear before continuing.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.muted(context),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SelfieFrame(state: state, progressLabel: progressLabel),
              const SizedBox(height: AppSpacing.lg),
              const _GuidanceCard(),
              if (state.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                _ScanError(
                  message: state.errorMessage!,
                  title: state.stage == ScanStage.validationFailed
                      ? 'This photo needs another try'
                      : null,
                  canOpenSettings: state.canOpenSettings,
                  canRetryValidation: state.canRetryValidation,
                  canReselect: state.canReselect,
                  onOpenSettings: controller.openSettings,
                  onRetryValidation: controller.validateForAnalysis,
                  onReselect: () => _chooseFromGallery(ref),
                ),
              ],
              if (analysisState.message != null) ...[
                const SizedBox(height: AppSpacing.md),
                _AnalysisError(
                  state: analysisState,
                  onRetry: selfie != null && state.localValidation != null
                      ? () => ref
                            .read(faceAnalysisControllerProvider.notifier)
                            .analyze(
                              selfie: selfie,
                              localValidation: state.localValidation!,
                            )
                      : null,
                  onReselect: () => _chooseFromGallery(ref),
                  onSignIn: () => _recoverExpiredSession(ref),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              // Choosing a photo is now the whole gallery interaction. It used
              // to be the first of three taps — choose, then "Validate selfie",
              // then "Analyze selfie" — and neither of the other two offered a
              // decision. Selection is the intent; the app acts on it.
              if (analysisState.status == FaceAnalysisStatus.success) ...[
                PrimaryButton(
                  label: 'View analysis',
                  icon: Icons.visibility_outlined,
                  onPressed: isBusy
                      ? null
                      : () => context.push(AppConstants.analysisRoute),
                ),
              ] else ...[
                PrimaryButton(
                  label: 'Take a photo',
                  icon: Icons.camera_alt_outlined,
                  // Opens the in-app live camera rather than handing off to
                  // the OS picker. Local guidance can only exist where the
                  // frames are, and the OS camera never gave us any.
                  onPressed: isBusy
                      ? null
                      : () => context.push(AppConstants.liveScanRoute),
                ),
                const SizedBox(height: AppSpacing.sm),
                SecondaryButton(
                  key: const ValueKey('gallery-choose'),
                  label: _galleryLabel(state, selfie != null),
                  icon: Icons.photo_library_outlined,
                  onPressed: isBusy ? null : () => _chooseFromGallery(ref),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _galleryLabel(ScanState state, bool hasSelfie) {
    if (state.isBusy && state.activeSource == SelfieSource.gallery) {
      return 'Preparing selfie...';
    }
    return hasSelfie ? 'Choose another photo' : 'Choose from gallery';
  }

  /// Picks a photo and runs the whole sequence.
  ///
  /// Any previous analysis is cleared first, so a new photo can never be
  /// confused with the result of the last one.
  Future<void> _chooseFromGallery(WidgetRef ref) async {
    ref.read(faceAnalysisControllerProvider.notifier).clear();
    await ref
        .read(scanControllerProvider.notifier)
        .chooseFromGalleryAndAnalyze();
  }

  Future<void> _beginNewScan(WidgetRef ref) async {
    ref.read(faceAnalysisControllerProvider.notifier).clear();
    await ref.read(scanControllerProvider.notifier).beginNewScan();
  }

  Future<void> _recoverExpiredSession(WidgetRef ref) {
    return ref.read(authControllerProvider.notifier).recoverExpiredSession();
  }
}

class _SelfieFrame extends StatelessWidget {
  const _SelfieFrame({required this.state, this.progressLabel});

  final ScanState state;

  /// What the app is doing right now, or null when it is waiting on the user.
  ///
  /// Drives both the scrim and what a screen reader announces, so the two can
  /// never disagree about whether anything is happening.
  final String? progressLabel;

  @override
  Widget build(BuildContext context) {
    final selfie = state.selfie;
    final info = AppTone.info.resolve(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: AspectRatio(
        // Was a fixed 340pt box. A selfie is portrait, so an aspect ratio
        // frames it correctly on a 320pt phone and a 720pt tablet alike,
        // instead of letterboxing on one and cropping on the other.
        aspectRatio: 3 / 4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: info.surface,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: info.border, width: AppBorders.emphasis),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (selfie == null)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.face_rounded,
                      size: AppIconSizes.hero * 2,
                      color: info.accent,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Center your face in the frame',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: info.onSurface),
                    ),
                  ],
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) => Image.file(
                    File(selfie.originalPath),
                    fit: BoxFit.cover,
                    // The on-device original can be 2048 px; the preview box is
                    // now measured rather than assumed.
                    cacheWidth: decodeWidthFor(context, constraints),
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          'Preview unavailable. Please choose another image.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: info.onSurface),
                        ),
                      ),
                    ),
                  ),
                ),
              if (progressLabel != null)
                ColoredBox(
                  color: Colors.black.withValues(alpha: 0.32),
                  child: Center(
                    // Fixed white: this sits on a scrim over the user own
                    // photo, whose brightness the theme knows nothing about.
                    child: AppProgress(
                      size: AppProgressSize.large,
                      color: Colors.white,
                      semanticLabel: progressLabel,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard();

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A heading, because five icon rows with no label read as decoration.
        // These are the checks the selfie is about to be measured against, and
        // saying so turns a list into an explanation.
        Text(
          'For the best result',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        const _TipRow(Icons.person_outline_rounded, 'One person only'),
        const _TipRow(Icons.face_outlined, 'Face fully visible'),
        const _TipRow(Icons.light_mode_outlined, 'Good, even lighting'),
        const _TipRow(Icons.blur_off_rounded, 'Avoid heavy blur'),
        const _TipRow(Icons.screen_rotation_outlined, 'Avoid extreme angles'),
      ],
    ),
  );
}

class _ScanError extends StatelessWidget {
  const _ScanError({
    required this.message,
    required this.canOpenSettings,
    required this.canRetryValidation,
    required this.canReselect,
    required this.onOpenSettings,
    required this.onRetryValidation,
    required this.onReselect,
    this.title,
  });

  final String message;

  /// A heading for the failure, when one adds something.
  ///
  /// A rejected photo gets one, because "This photo needs another try" frames
  /// what follows as a fixable property of the image rather than as an error
  /// the user caused. The message beneath it is the validator's own words —
  /// never a substitute reason invented to sound friendlier.
  final String? title;

  final bool canOpenSettings;
  final bool canRetryValidation;
  final bool canReselect;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetryValidation;
  final VoidCallback onReselect;

  @override
  Widget build(BuildContext context) => AppNotice(
    // Was the success tint. Every recovery action and every condition below is
    // unchanged — only which surface the failure is drawn on.
    tone: AppTone.danger,
    title: title,
    message: message,
    liveRegion: true,
    actions: [
      if (canOpenSettings)
        TertiaryButton(
          label: 'Open Settings',
          icon: Icons.settings_outlined,
          onPressed: onOpenSettings,
        ),
      if (canRetryValidation)
        TertiaryButton(
          label: 'Retry validation',
          icon: Icons.refresh_rounded,
          onPressed: onRetryValidation,
        ),
      if (canReselect)
        TertiaryButton(
          label: 'Choose another photo',
          icon: Icons.photo_library_outlined,
          onPressed: onReselect,
        ),
    ],
  );
}

class _AnalysisError extends StatelessWidget {
  const _AnalysisError({
    required this.state,
    required this.onReselect,
    required this.onSignIn,
    this.onRetry,
  });

  final FaceAnalysisState state;
  final VoidCallback? onRetry;
  final VoidCallback onReselect;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final needsSignIn =
        state.status == FaceAnalysisStatus.authenticationFailure;
    final needsAnotherPhoto =
        state.status == FaceAnalysisStatus.validationFailure ||
        (state.status == FaceAnalysisStatus.geminiFailure && !state.retryable);
    return AppNotice(
      tone: AppTone.danger,
      title: 'Analysis paused',
      message: state.message ?? 'Please try again.',
      liveRegion: true,
      // The same three-way choice as before, in the same order and under the
      // same conditions: retry if the failure is retryable, otherwise sign in,
      // otherwise choose another photo.
      actions: [
        if (state.retryable && onRetry != null)
          TertiaryButton(
            label: 'Retry analysis',
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          )
        else if (needsSignIn)
          TertiaryButton(
            label: 'Sign in again',
            icon: Icons.login_rounded,
            onPressed: onSignIn,
          )
        else if (needsAnotherPhoto)
          TertiaryButton(
            label: 'Choose another photo',
            icon: Icons.photo_library_outlined,
            onPressed: onReselect,
          ),
      ],
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs + 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.rose, size: AppIconSizes.sm),
        const SizedBox(width: AppSpacing.sm),
        // Expanded so a tip wraps instead of overflowing once the reader
        // raises their text size.
        Expanded(child: Text(label)),
      ],
    ),
  );
}
