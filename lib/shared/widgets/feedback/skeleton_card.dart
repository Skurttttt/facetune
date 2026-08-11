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
      duration: const Duration(milliseconds: 1200),
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
                Container(height: widget.imageHeight, decoration: _box(color)),
                const SizedBox(height: 16),
                FractionallySizedBox(
                  widthFactor: .6,
                  child: Container(height: 16, decoration: _box(color)),
                ),
                const SizedBox(height: 10),
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
