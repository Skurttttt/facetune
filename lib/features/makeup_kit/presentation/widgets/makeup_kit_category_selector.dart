import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../domain/entities/makeup_kit_category.dart';
import '../utils/makeup_kit_display.dart';

/// The Category field of the product form.
///
/// Looks like the form's other fields; a tap opens a bottom sheet listing the
/// categories. It replaces a dropdown whose open menu covered most of the
/// screen.
///
/// Presentation only. It shows [selected] and reports a pick through
/// [onSelected], with the same rule the dropdown had: any pick is reported,
/// including the current category, and dismissing the sheet reports nothing.
/// What a pick does to the rest of the form is still the page's decision.
class MakeupKitCategorySelector extends StatelessWidget {
  const MakeupKitCategorySelector({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final MakeupKitCategory selected;
  final ValueChanged<MakeupKitCategory> onSelected;

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<MakeupKitCategory>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _CategorySheet(selected: selected),
    );
    if (picked != null) onSelected(picked);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Category, ${selected.label}',
    hint: 'Choose a category',
    excludeSemantics: true,
    child: InkWell(
      key: const ValueKey('makeup-kit-category-field'),
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Category',
          suffixIcon: Icon(Icons.expand_more_rounded),
        ),
        child: Row(
          children: [
            Icon(selected.icon, size: AppIconSizes.sm),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(selected.label, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CategorySheet extends StatelessWidget {
  const _CategorySheet({required this.selected});

  final MakeupKitCategory selected;

  @override
  Widget build(BuildContext context) => ListView(
    shrinkWrap: true,
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xs,
        ),
        child: Semantics(
          header: true,
          child: Text(
            'Choose a category',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
      // Same order as the domain enum, as in the dropdown before.
      for (final category in MakeupKitCategory.values)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          leading: Icon(category.icon),
          title: Text(category.label),
          selected: category == selected,
          trailing: category == selected
              ? const Icon(Icons.check_rounded)
              : null,
          onTap: () => Navigator.of(context).pop(category),
        ),
    ],
  );
}
