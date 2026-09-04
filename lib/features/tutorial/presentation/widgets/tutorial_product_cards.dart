import 'package:flutter/material.dart';

import '../../domain/entities/look_product_snapshot.dart';
import '../../domain/entities/standard_look_entry.dart';
import '../../domain/entities/tutorial_shade_details.dart';
import '../utils/tutorial_labels.dart';
import 'tutorial_recommendation_section.dart';

export 'tutorial_recommendation_section.dart';

Color? _colorFromHex(String? hex) {
  if (hex == null) return null;
  final parsed = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return parsed == null ? null : Color(0xFF000000 | parsed);
}

/// Standard Mode adapter: brand-neutral recommendation authority only.
class StandardProductCard extends StatelessWidget {
  const StandardProductCard({required this.entries, super.key});

  final List<StandardLookEntry> entries;

  @override
  Widget build(BuildContext context) {
    return TutorialRecommendationSection(
      sectionLabel: TutorialLabels.suggestedShades,
      items: [
        for (final entry in entries)
          TutorialRecommendationItem(
            displayName: entry.shadeName,
            swatch: _colorFromHex(entry.colorHex),
            finish: entry.finish.trim().isEmpty ? null : entry.finish,
            intensity: switch (TutorialIntensity.fromCode(entry.intensity)) {
              final intensity? => TutorialLabels.intensityName(intensity),
              null => null,
            },
          ),
      ],
    );
  }
}

/// My Makeup Kit adapter: immutable owned-product snapshot authority only.
class MyMakeupKitProductCard extends StatelessWidget {
  const MyMakeupKitProductCard({required this.items, super.key});

  final List<LookProductSnapshotItem> items;

  @override
  Widget build(BuildContext context) {
    return TutorialRecommendationSection(
      sectionLabel: TutorialLabels.fromYourKit,
      items: [
        for (final item in items)
          TutorialRecommendationItem(
            // An unnamed product is described by its authoritative inventory
            // category, never by Standard data or an invented product name.
            displayName:
                item.productName ??
                TutorialLabels.inventoryCategory(item.kitCategory),
            swatch: _colorFromHex(item.color.value),
            finish: TutorialLabels.finishName(item.finish),
            // The immutable snapshot has no brand or per-product intensity.
            // Leaving both absent is the only truthful presentation.
          ),
      ],
    );
  }
}
