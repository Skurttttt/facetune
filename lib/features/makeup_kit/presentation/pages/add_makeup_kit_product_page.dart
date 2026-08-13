import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../domain/catalog/makeup_kit_finish_catalog.dart';
import '../../domain/entities/foundation_depth.dart';
import '../../domain/entities/foundation_undertone.dart';
import '../../domain/entities/makeup_kit_category.dart';
import '../../domain/entities/makeup_kit_finish.dart';
import '../../domain/entities/makeup_kit_product.dart';
import '../../domain/value_objects/normalized_hex_color.dart';
import '../controllers/makeup_kit_products_controller.dart';
import '../controllers/makeup_kit_products_state.dart';
import '../utils/makeup_kit_curated_shades.dart';
import '../utils/makeup_kit_display.dart';
import '../widgets/makeup_kit_color_picker.dart';
import '../widgets/makeup_kit_finish_selector.dart';
import '../widgets/makeup_kit_foundation_attributes_selector.dart';

/// My Makeup Kit → Add Product.
///
/// A single reactive form rather than a multi-step wizard: picking a
/// category immediately reshapes the rest of the form (allowed finishes,
/// Foundation-only fields) in place, matching
/// FACETUNE_MY_MAKEUP_KIT_GUIDE.md §10's "the form changes based on
/// category" requirement while keeping navigation simple.
class AddMakeupKitProductPage extends ConsumerStatefulWidget {
  const AddMakeupKitProductPage({this.product, super.key});

  final MakeupKitProduct? product;

  @override
  ConsumerState<AddMakeupKitProductPage> createState() =>
      _AddMakeupKitProductPageState();
}

class _AddMakeupKitProductPageState
    extends ConsumerState<AddMakeupKitProductPage> {
  static final _initialCategory = MakeupKitCategory.values.first;
  static final _initialShade = MakeupKitCuratedShades.forCategory(
    _initialCategory,
  ).first;

  late final TextEditingController _nameController;
  late MakeupKitCategory _category;
  late MakeupKitFinish _finish;
  late NormalizedHexColor _color;
  String? _colorLabel;
  FoundationDepth? _depth;
  FoundationUndertone? _undertone;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.productName);
    _category = product?.category ?? _initialCategory;
    _finish =
        product?.finish ??
        MakeupKitFinishCatalog.allowedFinishes(_initialCategory).first;
    _color = product?.color ?? _initialShade.color;
    _colorLabel = product?.colorLabel ?? _initialShade.label;
    _depth = product?.foundationDepth;
    _undertone = product?.foundationUndertone;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(
      makeupKitProductsControllerProvider.select(
        (state) => _isEditing
            ? state.mutatingIds.contains(widget.product!.id)
            : state.isCreating,
      ),
    );
    ref.listen<MakeupKitProductsState>(makeupKitProductsControllerProvider, (
      previous,
      next,
    ) {
      if (next.feedback == null || next.feedback == previous?.feedback) return;
      final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(next.feedback!),
          backgroundColor: next.feedbackIsError ? AppColors.error : null,
          action: next.sessionExpired
              ? SnackBarAction(
                  label: 'Sign in again',
                  onPressed: () => ref
                      .read(authControllerProvider.notifier)
                      .recoverExpiredSession(),
                )
              : null,
        ),
      );
      ref.read(makeupKitProductsControllerProvider.notifier).clearFeedback();
    });

    final isFoundation = _category == MakeupKitCategory.foundation;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Product' : 'Add Product')),
      body: SafeArea(
        child: PageFrame(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Category', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<MakeupKitCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final category in MakeupKitCategory.values)
                      DropdownMenuItem(
                        value: category,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(category.icon, size: AppIconSizes.sm),
                            const SizedBox(width: AppSpacing.xs),
                            Text(category.label),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (category) {
                    if (category != null) _onCategoryChanged(category);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product name (optional)',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.lg),
                MakeupKitColorPicker(
                  category: _category,
                  selectedColor: _color,
                  selectedLabel: _colorLabel,
                  onColorSelected: (color, label) {
                    setState(() {
                      _color = color;
                      _colorLabel = label;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                MakeupKitFinishSelector(
                  options: MakeupKitFinishCatalog.allowedFinishes(
                    _category,
                  ).toList(growable: false),
                  selected: _finish,
                  onSelected: (finish) => setState(() => _finish = finish),
                ),
                if (isFoundation) ...[
                  const SizedBox(height: AppSpacing.lg),
                  MakeupKitFoundationAttributesSelector(
                    selectedDepth: _depth,
                    selectedUndertone: _undertone,
                    onDepthSelected: (depth) => setState(() => _depth = depth),
                    onUndertoneSelected: (undertone) =>
                        setState(() => _undertone = undertone),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: isSaving
                      ? 'Saving…'
                      : _isEditing
                      ? 'Save Changes'
                      : 'Add to My Makeup Kit',
                  icon: Icons.check_rounded,
                  onPressed: isSaving ? null : _submit,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onCategoryChanged(MakeupKitCategory category) {
    final allowedFinishes = MakeupKitFinishCatalog.allowedFinishes(category);
    final shade = MakeupKitCuratedShades.forCategory(category).first;
    setState(() {
      _category = category;
      _finish = allowedFinishes.contains(_finish)
          ? _finish
          : allowedFinishes.first;
      if (category != MakeupKitCategory.foundation) {
        _depth = null;
        _undertone = null;
      }
      _color = shade.color;
      _colorLabel = shade.label;
    });
  }

  Future<void> _submit() async {
    final isFoundation = _category == MakeupKitCategory.foundation;
    final name = _nameController.text.trim();
    final draft = MakeupKitProductDraft(
      category: _category,
      productName: name.isEmpty ? null : name,
      color: _color,
      colorLabel: _colorLabel,
      finish: _finish,
      foundationDepth: isFoundation ? _depth : null,
      foundationUndertone: isFoundation ? _undertone : null,
    );
    final notifier = ref.read(makeupKitProductsControllerProvider.notifier);
    final succeeded = _isEditing
        ? await notifier.updateProduct(widget.product!.id, draft)
        : await notifier.createProduct(draft);
    if (!mounted) return;
    if (succeeded && context.mounted) context.pop();
  }
}
