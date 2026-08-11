import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../controllers/makeup_preview_controller.dart';
import '../controllers/makeup_preview_state.dart';

class PreviewResultPage extends ConsumerWidget {
  const PreviewResultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(makeupPreviewControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('AI makeup preview')),
      body: SafeArea(
        child: PageFrame(
          child: switch (state.status) {
            MakeupPreviewStatus.generating => const Center(
              child: LoadingState(
                label: 'Applying your makeup while preserving your look…',
              ),
            ),
            MakeupPreviewStatus.failure => Center(
              child: StatusState(
                title: 'Preview generation paused',
                message: [
                  state.message ?? 'Please try again.',
                  if (state.technicalCode != null)
                    'Diagnostic: ${state.technicalCode}',
                ].join('\n\n'),
                icon: Icons.error_outline_rounded,
                actionLabel: state.retryable ? 'Try again' : null,
                onAction: state.retryable
                    ? () => ref
                          .read(makeupPreviewControllerProvider.notifier)
                          .retry()
                    : null,
              ),
            ),
            MakeupPreviewStatus.success => _PreviewContent(
              state: state,
              onVariation: () => ref
                  .read(makeupPreviewControllerProvider.notifier)
                  .generateVariation(),
            ),
            MakeupPreviewStatus.idle => const Center(
              child: StatusState(
                title: 'Preview unavailable',
                message:
                    'Generate a recommendation before creating your preview.',
                icon: Icons.info_outline_rounded,
              ),
            ),
          },
        ),
      ),
    );
  }
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({required this.state, required this.onVariation});

  final MakeupPreviewState state;
  final VoidCallback onVariation;

  @override
  Widget build(BuildContext context) {
    final preview = state.preview!;
    return ListView(
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(
          'Your look, reimagined',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Variation ${preview.generationNumber}. AI identity preservation is a goal, so review the result and regenerate if it does not feel like you.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ImagePanel(label: 'Original', imageUrl: preview.originalImageUrl),
        const SizedBox(height: AppSpacing.md),
        _ImagePanel(
          label: 'Makeup preview',
          imageUrl: preview.generatedImageUrl,
        ),
        const SizedBox(height: AppSpacing.lg),
        SecondaryButton(
          label: 'Generate another variation',
          icon: Icons.refresh_rounded,
          onPressed: onVariation,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _ImagePanel extends StatelessWidget {
  const _ImagePanel({required this.label, required this.imageUrl});

  final String label;
  final String imageUrl;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: label,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const StatusState(
                title: 'Image unavailable',
                message: 'Refresh or generate another variation.',
                icon: Icons.broken_image_outlined,
              ),
            ),
            Positioned(
              left: AppSpacing.sm,
              top: AppSpacing.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(label, style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
