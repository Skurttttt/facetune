import 'package:flutter/material.dart';

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
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${style.name} makeup style. ${style.description}',
      onTap: onSelected,
      child: ExcludeSemantics(
        child: Material(
          color: isSelected ? AppColors.petal : colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            side: BorderSide(
              color: isSelected ? AppColors.rose : colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
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
                        child: Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          key: ValueKey(isSelected),
                          color: isSelected ? AppColors.rose : AppColors.taupe,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    style.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      style.description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.taupe),
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
