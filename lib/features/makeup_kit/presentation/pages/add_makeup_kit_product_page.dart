import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
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
import '../widgets/makeup_kit_category_selector.dart';
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
      // `feedbackIsError` is the controller's own classification, so the tone
      // reads it rather than re-deriving one. A save that worked now looks
      // different from one that failed, instead of both being grey.
      showAppSnackBar(
        context,
        message: next.feedback!,
        tone: next.feedbackIsError ? AppTone.danger : AppTone.success,
        actionLabel: next.sessionExpired ? 'Sign in again' : null,
        onAction: next.sessionExpired
            ? () => ref
                  .read(authControllerProvider.notifier)
                  .recoverExpiredSession()
            : null,
      );
      ref.read(makeupKitProductsControllerProvider.notifier).clearFeedback();
    });

    final isFoundation = _category == MakeupKitCategory.foundation;
    final textTheme = Theme.of(context).textTheme;
    final editedProduct = widget.product;

    return Scaffold(
      appBar: FaceTuneTopBar(
        title: _isEditing ? 'Edit Product' : 'Add Product',
      ),
      body: SafeArea(
        child: PageFrame(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A heading and one line of guidance, in place of the notice
                // box that used to open the form. Editing names the product
                // rather than repeating the app bar's "Edit Product".
                Semantics(
                  header: true,
                  child: Text(
                    editedProduct == null
                        ? 'Add to your kit'
                        : editedProduct.productName ??
                              editedProduct.colorLabel ??
                              editedProduct.category.label,
                    style: textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Choose the closest shade first. You can fine-tune it if '
                  'you need to.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _FormSection(
                  title: 'Product',
                  children: [
                    // Same value and the same transition as the dropdown it
                    // replaces; only the choosing surface changed.
                    MakeupKitCategorySelector(
                      selected: _category,
                      onSelected: _onCategoryChanged,
                    ),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product name (optional)',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // The picker and the two selectors below carry their own
                // headings, so their sections do not add another.
                _FormSection(
                  children: [
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
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _FormSection(
                  children: [
                    MakeupKitFinishSelector(
                      options: MakeupKitFinishCatalog.allowedFinishes(
                        _category,
                      ).toList(growable: false),
                      selected: _finish,
                      onSelected: (finish) => setState(() => _finish = finish),
                    ),
                  ],
                ),
                if (isFoundation) ...[
                  const SizedBox(height: AppSpacing.md),
                  _FormSection(
                    title: 'Foundation details',
                    children: [
                      MakeupKitFoundationAttributesSelector(
                        selectedDepth: _depth,
                        selectedUndertone: _undertone,
                        onDepthSelected: (depth) =>
                            setState(() => _depth = depth),
                        onUndertoneSelected: (undertone) =>
                            setState(() => _undertone = undertone),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: isSaving
                      ? 'Saving…'
                      : _isEditing
                      ? 'Save changes'
                      : 'Add product',
                  icon: Icons.check_rounded,
                  onPressed: isSaving ? null : _submit,
                ),
                // Clear of the system navigation (the page is in a SafeArea);
                // no longer a tall empty tail under the button.
                const SizedBox(height: AppSpacing.lg),
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

/// One group of the form, on its own card, so the form reads as a few
/// distinct steps rather than one long run of controls.
///
/// [title] is optional: the shade picker and the finish selector already
/// carry their own headings.
class _FormSection extends StatelessWidget {
  const _FormSection({required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
    // Full width, whatever is inside. The page's column aligns to the start,
    // so a card otherwise shrinks to its content: a section of two finish
    // chips came out half as wide as the sections around it.
    width: double.infinity,
    child: _card(context),
  );

  Widget _card(BuildContext context) => Card(
    // The themed card AppCard draws, but not a semantic container: a
    // container merges every control inside it into one node, so a screen
    // reader heard "Product, Category, Foundation, Product name" as a single
    // item and could not reach the fields or shade tiles one by one.
    semanticContainer: false,
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: _content(context),
    ),
  );

  Widget _content(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (title != null) ...[
        Semantics(
          header: true,
          child: Text(title!, style: Theme.of(context).textTheme.titleSmall),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: AppSpacing.md),
        children[i],
      ],
    ],
  );
}
