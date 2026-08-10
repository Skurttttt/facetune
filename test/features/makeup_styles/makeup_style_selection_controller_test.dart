import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/makeup_styles/domain/entities/makeup_style.dart';
import 'package:facetune/features/makeup_styles/presentation/controllers/makeup_style_selection_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selection and confirmation persist in the scan-session provider', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(
      makeupStyleSelectionControllerProvider.notifier,
    );
    final softGlam = MakeupStyleCatalog.byId(MakeupStyleId.softGlam);

    controller.select(softGlam);
    controller.confirm();

    final state = container.read(makeupStyleSelectionControllerProvider);
    expect(state.selectedStyle, same(softGlam));
    expect(state.selectedStyle?.code, 'soft_glam');
    expect(state.isConfirmed, isTrue);
  });

  test('changing a confirmed style requires confirmation again', () {
    final controller = MakeupStyleSelectionController();
    addTearDown(controller.dispose);
    controller
      ..select(MakeupStyleCatalog.byId(MakeupStyleId.softGlam))
      ..confirm()
      ..select(MakeupStyleCatalog.byId(MakeupStyleId.natural));

    expect(controller.state.selectedStyle?.id, MakeupStyleId.natural);
    expect(controller.state.isConfirmed, isFalse);
  });
}
