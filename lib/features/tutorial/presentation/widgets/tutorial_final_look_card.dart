import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../utils/tutorial_labels.dart';
import 'tutorial_image_viewer.dart';

/// The canonical final preview, reachable from every step.
///
/// A tutorial step answers "where am I applying this?"; this answers "what is
/// it supposed to end up looking like?". Before QA-5 the second question was
/// only answerable on the last step, which is the one step where it no longer
/// matters — by then the work is done. It is now present throughout, because
/// the answer is most useful while the user is still mid-application.
///
/// [url] is the same signed URL for the same canonical preview the caller was
/// handed at navigation time. Nothing here generates a second final image,
/// requests one, or derives one from the guideline: there is one canonical
/// preview per look, and this shows it.
///
/// [expanded] chooses between two presentations of that one artifact. Every
/// step gets the compact reference, which stays out of the way of the
/// instructions; the last step keeps the full-size image it has always shown,
/// because at that point the finished look *is* the content of the step. Both
/// open the same viewer.
class TutorialFinalLookCard extends StatelessWidget {
  const TutorialFinalLookCard({
    required this.url,
    this.expanded = false,
    super.key,
  });

  final String url;

  final bool expanded;

  void _open(BuildContext context) => TutorialImageViewer.open(
    context,
    url: url,
    title: TutorialLabels.yourFinalLook,
    semanticLabel: TutorialLabels.yourFinalLook,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final heading = Text(
                TutorialLabels.yourFinalLook,
                style: theme.textTheme.titleSmall,
              );
              // The hint is the first thing to go when space runs out. It
              // duplicates what the semantics label already says and what a
              // tappable image already implies, so dropping it costs nothing —
              // whereas ellipsizing the heading beside it would cost the one
              // piece of text that names the section.
              final tight =
                  constraints.maxWidth < 260 ||
                  MediaQuery.textScalerOf(context).scale(12) > 18;
              if (tight) return heading;
              return Row(
                children: [
                  Expanded(child: heading),
                  Text(
                    TutorialLabels.tapToEnlarge,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted(context),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          // The heading above stays its own node; only the image is the
          // button, so a screen reader reads a labelled section containing one
          // action rather than one long merged string.
          Semantics(
            button: true,
            container: true,
            excludeSemantics: true,
            label: TutorialLabels.viewFinalLook,
            child: InkWell(
              onTap: () => _open(context),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: PrivateImage(url: url),
                ),
              ),
            ),
          ),
        ],
      );
    }

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
