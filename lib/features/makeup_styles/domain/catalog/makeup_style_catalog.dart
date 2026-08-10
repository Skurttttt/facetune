import '../entities/makeup_style.dart';

abstract final class MakeupStyleCatalog {
  static const styles = <MakeupStyle>[
    MakeupStyle(
      id: MakeupStyleId.natural,
      code: 'natural',
      name: 'Natural',
      description: 'Fresh skin, soft definition, and effortless polish.',
    ),
    MakeupStyle(
      id: MakeupStyleId.everyday,
      code: 'everyday',
      name: 'Everyday',
      description: 'Balanced color designed for an easy daily routine.',
    ),
    MakeupStyle(
      id: MakeupStyleId.office,
      code: 'office',
      name: 'Office',
      description: 'Refined neutrals with clean, confident definition.',
    ),
    MakeupStyle(
      id: MakeupStyleId.softGlam,
      code: 'soft_glam',
      name: 'Soft Glam',
      description: 'Diffused eyes, luminous skin, and softly sculpted color.',
    ),
    MakeupStyle(
      id: MakeupStyleId.fullGlam,
      code: 'full_glam',
      name: 'Full Glam',
      description: 'High-impact definition with a polished statement finish.',
    ),
    MakeupStyle(
      id: MakeupStyleId.bridal,
      code: 'bridal',
      name: 'Bridal',
      description: 'Romantic radiance with timeless, camera-ready detail.',
    ),
    MakeupStyle(
      id: MakeupStyleId.korean,
      code: 'korean',
      name: 'Korean',
      description: 'Glass-skin glow, softly flushed color, and delicate eyes.',
    ),
    MakeupStyle(
      id: MakeupStyleId.cleanGirl,
      code: 'clean_girl',
      name: 'Clean Girl',
      description: 'Sleek brows, healthy glow, and minimal tonal color.',
    ),
    MakeupStyle(
      id: MakeupStyleId.party,
      code: 'party',
      name: 'Party',
      description: 'Playful shine and bolder definition for evening light.',
    ),
    MakeupStyle(
      id: MakeupStyleId.dateNight,
      code: 'date_night',
      name: 'Date Night',
      description: 'Romantic warmth with softly alluring eyes and lips.',
    ),
    MakeupStyle(
      id: MakeupStyleId.noMakeupMakeup,
      code: 'no_makeup_makeup',
      name: 'No Makeup Makeup',
      description: 'Barely-there enhancement that lets natural features lead.',
    ),
    MakeupStyle(
      id: MakeupStyleId.oldMoney,
      code: 'old_money',
      name: 'Old Money',
      description: 'Understated elegance in quiet, timeless neutral tones.',
    ),
  ];

  static MakeupStyle byId(MakeupStyleId id) =>
      styles.firstWhere((style) => style.id == id);
}
