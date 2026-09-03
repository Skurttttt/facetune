import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../surfaces/app_card.dart';

class SkeletonCard extends StatefulWidget {
  const SkeletonCard({super.key, this.imageHeight = 140});

  final double imageHeight;

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.shimmer,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading content',
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final color = Color.lerp(
            Theme.of(context).colorScheme.surfaceContainerHighest,
            Theme.of(context).colorScheme.surfaceContainerLow,
            _controller.value,
          )!;
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Omitted entirely at zero rather than drawn as a zero-height
                // box, so a caller previewing rows that have no image does not
                // also inherit the gap where one would have been. A skeleton
                // that promises a picture and then resolves to text is a small
                // lie about what is coming.
                if (widget.imageHeight > 0) ...[
                  Container(
                    height: widget.imageHeight,
                    decoration: _box(color),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                FractionallySizedBox(
                  widthFactor: .6,
                  child: Container(height: 16, decoration: _box(color)),
                ),
                const SizedBox(height: AppSpacing.xs + 2),
                FractionallySizedBox(
                  widthFactor: .85,
                  child: Container(height: 12, decoration: _box(color)),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );

  BoxDecoration _box(Color color) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(AppRadii.sm),
  );
}
