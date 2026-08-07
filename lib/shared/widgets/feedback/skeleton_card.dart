import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../surfaces/app_card.dart';

class SkeletonCard extends StatefulWidget {
  const SkeletonCard({super.key});

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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final color = Color.lerp(
        AppColors.sand,
        AppColors.petal,
        _controller.value,
      )!;
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 140, decoration: _box(color)),
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
  );

  BoxDecoration _box(Color color) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(AppRadii.sm),
  );
}
