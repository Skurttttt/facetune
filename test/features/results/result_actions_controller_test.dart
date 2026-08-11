import 'package:facetune/features/preview/data/models/generated_preview_dto.dart';
import 'package:facetune/features/preview/domain/entities/generated_preview.dart';
import 'package:facetune/features/results/domain/services/result_share_service.dart';
import 'package:facetune/features/results/presentation/controllers/result_actions_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/generated_preview_response_fixture.dart';

void main() {
  late GeneratedPreview preview;

  setUp(() {
    preview = GeneratedPreviewDto.fromResponse(validGeneratedPreviewResponse)
        .toDomain(
          originalImageUrl: 'https://signed.example/original',
          generatedImageUrl: 'https://signed.example/generated',
        );
  });

  test('save and favorite state remains keyed to the generated preview', () {
    final controller = ResultActionsController(_FakeShareService());
    addTearDown(controller.dispose);

    controller.toggleFavorite(preview.id);

    expect(controller.state.isSaved(preview.id), isTrue);
    expect(controller.state.isFavorite(preview.id), isTrue);

    controller.toggleSaved(preview.id);

    expect(controller.state.isSaved(preview.id), isFalse);
    expect(controller.state.isFavorite(preview.id), isFalse);
  });

  test('share delegates only the generated preview and style name', () async {
    final service = _FakeShareService();
    final controller = ResultActionsController(service);
    addTearDown(controller.dispose);

    await controller.share(preview: preview, styleName: 'Soft Glam');

    expect(service.previewId, preview.id);
    expect(service.styleName, 'Soft Glam');
    expect(controller.state.isSharing, isFalse);
    expect(controller.state.isError, isFalse);
  });

  test('share failures return friendly action feedback', () async {
    final controller = ResultActionsController(
      _FakeShareService(shouldFail: true),
    );
    addTearDown(controller.dispose);

    await controller.share(preview: preview, styleName: 'Soft Glam');

    expect(controller.state.isError, isTrue);
    expect(controller.state.feedback, 'Sharing failed safely.');
  });
}

class _FakeShareService implements ResultShareService {
  _FakeShareService({this.shouldFail = false});

  final bool shouldFail;
  String? previewId;
  String? styleName;

  @override
  Future<void> share({
    required GeneratedPreview preview,
    required String styleName,
  }) async {
    if (shouldFail) {
      throw const ResultShareFailure('Sharing failed safely.');
    }
    previewId = preview.id;
    this.styleName = styleName;
  }
}
