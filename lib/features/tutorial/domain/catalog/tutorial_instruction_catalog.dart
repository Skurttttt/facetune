import '../entities/tutorial_category.dart';
import '../entities/tutorial_guide_type.dart';
import '../entities/tutorial_instruction.dart';

/// How to read the drawn guides, per category.
///
/// These instructions describe the **guide vocabulary**, not the user's face.
/// That distinction is what makes them truthful without any per-look data: the
/// tutorial knows which marks the renderer was asked to draw for a category, so
/// it can say what each one means, while never claiming where the makeup
/// actually sits. Anything specific to this look — the shade, the finish, the
/// intensity, the goal — comes from validated upstream data and is rendered
/// separately.
///
/// Each set references only guide types that this category's renderer prompt
/// actually asks for. Blush is told to draw a footprint boundary, a strongest
/// anchor and a fade direction, so its instructions speak of `●`, `━` and `→`
/// and never of a dashed blend zone. Referencing a mark the renderer was never
/// asked to draw would send the user hunting for something that is not there.
///
/// Deliberately 2–4 items each, matching the authoring guidance on
/// [TutorialInstructionSequence].
abstract final class TutorialInstructionCatalog {
  /// The instructions for [category].
  ///
  /// Total over the vocabulary: every category has a set, so a step can never
  /// fall back to bare wording.
  static TutorialInstructionSequence forCategory(TutorialCategory category) =>
      _catalog[category]!;

  static final Map<TutorialCategory, TutorialInstructionSequence> _catalog = {
    TutorialCategory.foundation: _sequence(<_Item>[
      _Item(
        TutorialGuideType.placementBoundary,
        'Find the coverage edge',
        'Look for the solid guide around the marked face area. Apply only '
            'inside it, and stop when you reach that solid boundary.',
      ),
      _Item(
        TutorialGuideType.blendZone,
        'Soften the outer edge',
        'At each dashed guide near the coverage edge, keep blending until the '
            'product fades into bare skin with no visible border.',
      ),
      _Item(
        TutorialGuideType.direction,
        'Move from centre to edge',
        'Follow each arrow from the centre of the marked area toward its outer '
            'edge. Stop where the arrow meets the boundary or fade zone.',
      ),
    ]),
    TutorialCategory.concealer: _sequence(<_Item>[
      _Item(
        TutorialGuideType.placementBoundary,
        'Locate each correction zone',
        'Find the solid guide beneath an eye or around another marked area. '
            'Place concealer inside that guide and stop at its edge.',
      ),
      _Item(
        TutorialGuideType.blendZone,
        'Tap across the fade zone',
        'Tap over the dashed guide around each correction zone until its edge '
            'melts into the surrounding skin.',
      ),
      _Item(
        TutorialGuideType.direction,
        'Blend away from the centre',
        'Follow the arrows from the fuller part of each marked zone toward its '
            'outer edge. Stop when the arrow ends.',
      ),
    ]),
    TutorialCategory.contourBronzer: _sequence(<_Item>[
      _Item(
        TutorialGuideType.placementBoundary,
        'Find the sculpting band',
        'Look for the solid guide along a marked cheekbone, temple, jaw, or '
            'nose area. Place product within that band, not beyond its edges.',
      ),
      _Item(
        TutorialGuideType.direction,
        'Sweep along the feature',
        'Follow the arrows along each marked band so the depth travels in the '
            'shown direction. Stop where that band ends.',
      ),
      _Item(
        TutorialGuideType.blendZone,
        'Buff the dashed edge',
        'Buff across each dashed guide bordering the band until the depth '
            'fades without leaving a stripe.',
      ),
    ]),
    TutorialCategory.blush: _sequence(<_Item>[
      _Item(
        TutorialGuideType.startAnchor,
        'Anchor the cheek colour',
        'Find the dot on the marked cheek area and place the first colour '
            'there. Keep this anchor as the strongest point.',
      ),
      _Item(
        TutorialGuideType.placementBoundary,
        'Fill the cheek footprint',
        'Spread colour from the anchor through the solid guide on the cheek. Stop at '
            'the solid boundary so the blush does not grow past its footprint.',
      ),
      _Item(
        TutorialGuideType.direction,
        'Fade toward the outer edge',
        'Follow the arrows away from the cheek anchor toward the outer end of '
            'the footprint. Finish as the arrows meet the boundary.',
      ),
    ]),
    TutorialCategory.highlighter: _sequence(<_Item>[
      _Item(
        TutorialGuideType.startAnchor,
        'Tap the marked high point',
        'Find each dot on a visibly marked high point and tap highlighter '
            'there first. Do not add unmarked highlight points.',
      ),
      _Item(
        TutorialGuideType.placementBoundary,
        'Follow the narrow trace',
        'Move only inside the solid guide extending from each dot. Stop where '
            'that narrow trace ends instead of widening it.',
      ),
    ]),
    TutorialCategory.eyebrows: _sequence(<_Item>[
      _Item(
        TutorialGuideType.startAnchor,
        'Locate the brow anchors',
        'The dots mark the parts of the brow that changed — the start, the '
            'arch, or the tail. Only those need work.',
      ),
      _Item(
        TutorialGuideType.placementBoundary,
        'Trace the target brow edge',
        'Follow the solid guide along the marked upper or lower brow edge. '
            'Fill up to that guide and stop there.',
      ),
      _Item(
        TutorialGuideType.direction,
        'Match the hair direction',
        'Draw short strokes along the arrows between the marked brow anchors. '
            'Stop when the arrows or solid edge end.',
      ),
    ]),
    TutorialCategory.eyeshadow: _sequence(<_Item>[
      _Item(
        TutorialGuideType.placementBoundary,
        'Identify each eye zone',
        'Find each solid guide on the lid, crease, or marked corner. Apply '
            'shadow inside one zone at a time and stop at its solid edge.',
      ),
      _Item(
        TutorialGuideType.blendZone,
        'Blend across the transition',
        'Where a dashed guide separates eye zones, blend across that dashed '
            'transition until the zones meet without a hard line.',
      ),
      _Item(
        TutorialGuideType.direction,
        'Move through the marked zone',
        'Follow the arrows within the lid, crease, or corner zone they cross. '
            'Stop as each arrow reaches its boundary or fade line.',
      ),
    ]),
    TutorialCategory.eyeliner: _sequence(<_Item>[
      _Item(
        TutorialGuideType.startAnchor,
        'Start on the lash line',
        'Find the dot on the marked lash line and begin exactly there. Do not '
            'extend inward unless the dot is placed at the inner corner.',
      ),
      _Item(
        TutorialGuideType.placementBoundary,
        'Trace the lash path',
        'Follow the solid guide along the lash line and into the wing. Match '
            'its thickness as it changes, and stop at the guide endpoint.',
      ),
      _Item(
        TutorialGuideType.direction,
        'Extend to the wing endpoint',
        'Follow the outward arrow from the outer corner. Stop where the solid '
            'wing guide ends so its length and angle stay intact.',
      ),
    ]),
    TutorialCategory.lips: _sequence(<_Item>[
      _Item(
        TutorialGuideType.placementBoundary,
        'Trace the target lip border',
        'Follow the solid guide around the Cupid bow, sides, and lower lip. '
            'Where it differs from your natural border, follow the solid guide.',
      ),
      _Item(
        TutorialGuideType.startAnchor,
        'Set the bow and corners',
        'Use the dots at the Cupid bow or lip corners as anchors before '
            'filling. Connect only the anchors that are shown.',
      ),
      _Item(
        TutorialGuideType.direction,
        'Fill inward',
        'Follow the arrows from the solid border toward the lip centre. Stop '
            'before crossing the opposite border so the edge stays crisp.',
      ),
    ]),
  };

  static TutorialInstructionSequence _sequence(List<_Item> items) =>
      TutorialInstructionSequence.from(<TutorialInstructionStep>[
        for (var index = 0; index < items.length; index += 1)
          TutorialInstructionStep(
            sequence: index + 1,
            guideType: items[index].guideType,
            shortTitle: items[index].shortTitle,
            instruction: items[index].instruction,
          ),
      ]);
}

/// Authoring shorthand so the catalog reads as a table rather than as a wall of
/// repeated constructor arguments. The sequence numbers are derived from list
/// position, which is the only place they can be assigned without risk of a gap.
class _Item {
  const _Item(this.guideType, this.shortTitle, this.instruction);

  final TutorialGuideType guideType;
  final String shortTitle;
  final String instruction;
}
