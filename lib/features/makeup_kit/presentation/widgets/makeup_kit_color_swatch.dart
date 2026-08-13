import 'package:flutter/material.dart';

import '../../domain/value_objects/normalized_hex_color.dart';
import '../utils/makeup_kit_display.dart';

/// A small circular preview of a registered product's color.
class MakeupKitColorSwatch extends StatelessWidget {
  const MakeupKitColorSwatch({required this.color, super.key, this.size = 28});

  final NormalizedHexColor color;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Color swatch ${color.value}',
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.toColor(),
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
  );
}
