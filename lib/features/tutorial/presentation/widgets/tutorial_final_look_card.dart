import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../utils/tutorial_labels.dart';
import 'tutorial_image_viewer.dart';

/// The compact canonical final preview, reachable from every tutorial step.
///
/// [url] is the same signed URL for the same canonical preview handed to the
/// tutorial at navigation time. This widget never generates, requests, or
/// derives another image; it only presents that one preview and opens the
/// existing canonical viewer.
class TutorialFinalLookCard extends StatelessWidget {
  const TutorialFinalLookCard({required this.url, super.key});

  final String url;

  void _open(BuildContext context) => TutorialImageViewer.open(
    context,
    url: url,
    title: TutorialLabels.yourFinalLook,
    semanticLabel: TutorialLabels.yourFinalLook,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label:
          '${TutorialLabels.yourFinalLook}. '
          '${TutorialLabels.finalLookHint}. '
          '${TutorialLabels.tapToEnlarge}.',
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        onTap: () => _open(context),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: SizedBox(
                width: 54,
                height: 72,
                child: PrivateImage(url: url),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    TutorialLabels.yourFinalLook,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    TutorialLabels.finalLookHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.zoom_out_map, size: 20, color: AppColors.muted(context)),
          ],
        ),
      ),
    );
  }
}
