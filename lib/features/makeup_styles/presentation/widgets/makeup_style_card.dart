import 'package:flutter/material.dart';

import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/entities/makeup_style.dart';

class MakeupStyleCard extends StatelessWidget {
  const MakeupStyleCard({
    required this.style,
    required this.isSelected,
    required this.onSelected,
    super.key,
  });

  final MakeupStyle style;
  final bool isSelected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // The selected surface used to be the fixed `AppColors.petal`, which keeps
    // its own brightness in dark mode while the label inside it followed the
    // theme to near-white — light text on a near-white card. The info role is
    // the same pink in light mode and a dark tint in dark mode, and it brings a
    // foreground that is guaranteed to read on whichever it resolves to.
    final selected = AppTone.info.resolve(context);
    final surface = isSelected ? selected.surface : colorScheme.surface;
    final onSurface = isSelected ? selected.onSurface : colorScheme.onSurface;
    final muted = isSelected
        ? selected.onSurface.withValues(alpha: .72)
        : AppColors.muted(context);

    return Semantics(
      button: true,
      enabled: onSelected != null,
      selected: isSelected,
      label: '${style.name} makeup style. ${style.description}',
      onTap: onSelected,
      child: ExcludeSemantics(
        child: Material(
          color: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            side: BorderSide(
              color: isSelected ? selected.accent : colorScheme.outlineVariant,
              width: isSelected ? AppBorders.emphasis : AppBorders.hairline,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onSelected,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          // A fixed light-on-dark pair, readable in either
                          // theme, so the style's own mark stays constant while
                          // the card around it changes.
                          color: AppColors.blush,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _iconFor(style.id),
                          color: AppColors.roseDark,
                          size: AppIconSizes.md,
                        ),
                      ),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: AppDurations.quick,
                        switchInCurve: AppCurves.standard,
                        child: Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          key: ValueKey(isSelected),
                          color: isSelected ? selected.accent : muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    style.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Expanded(
                    child: Text(
                      style.description,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(MakeupStyleId id) => switch (id) {
    MakeupStyleId.natural => Icons.eco_outlined,
    MakeupStyleId.everyday => Icons.wb_sunny_outlined,
    MakeupStyleId.office => Icons.work_outline_rounded,
    MakeupStyleId.softGlam => Icons.auto_awesome_rounded,
    MakeupStyleId.fullGlam => Icons.diamond_outlined,
    MakeupStyleId.bridal => Icons.local_florist_outlined,
    MakeupStyleId.korean => Icons.water_drop_outlined,
    MakeupStyleId.cleanGirl => Icons.spa_outlined,
    MakeupStyleId.party => Icons.celebration_outlined,
    MakeupStyleId.dateNight => Icons.favorite_border_rounded,
    MakeupStyleId.noMakeupMakeup => Icons.face_retouching_natural_outlined,
    MakeupStyleId.oldMoney => Icons.workspace_premium_outlined,
  };
}
