import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';

class BeautyImage extends StatelessWidget {
  const BeautyImage({
    super.key,
    this.height = 260,
    this.radius = AppRadii.lg,
    this.alignment = Alignment.center,
    this.overlay,
  });
  final double height;
  final double radius;
  final Alignment alignment;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/beauty_portrait.png',
            fit: BoxFit.cover,
            alignment: alignment,
          ),
          ?overlay,
        ],
      ),
    ),
  );
}
