import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';

/// The TARGET LOOK reference: the canonical premium preview, unmodified.
///
/// Shown as a thumbnail that expands to a full-screen view. Both show the same
/// stored image at its own aspect ratio, with no crop, filter, overlay or
/// recolouring — the target is the exact preview the user already paid for and
/// is working toward, so anything applied to it here would misrepresent the
/// destination.
///
/// MVP shows the full preview. Category-focused crops are a later refinement
/// and must be derived from these pixels, never redrawn by a model.
class TutorialV3TargetReference extends StatelessWidget {
  const TutorialV3TargetReference({
    required this.imageUrl,
    super.key,
    this.height = 132,
  });

  final String imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Target look. Tap to view the full preview.',
    // One node, one label: the thumbnail and its two captions would otherwise
    // be read out as three separate items before the control itself.
    excludeSemantics: true,
    child: InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 3 / 4,
                child: PrivateImage(url: imageUrl, semanticLabel: null),
              ),
              Expanded(
                child: ColoredBox(
                  color: AppColors.petal,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your finished look',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Tap to enlarge',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void _open(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: Colors.transparent,
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            // BoxFit.contain: the whole preview, never cropped to fit a frame.
            child: PrivateImage(
              url: imageUrl,
              fit: BoxFit.contain,
              semanticLabel: 'Your finished look',
            ),
          ),
          IconButton.filledTonal(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
          ),
        ],
      ),
    ),
  );
}
