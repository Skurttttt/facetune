import 'dart:async';

import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/analysis/domain/entities/face_analysis.dart';
import 'package:facetune/features/analysis/domain/repositories/face_analysis_repository.dart';
import 'package:facetune/features/analysis/domain/usecases/analyze_face.dart';
import 'package:facetune/features/analysis/presentation/controllers/face_analysis_controller.dart';
import 'package:facetune/features/analysis/presentation/controllers/face_analysis_state.dart';
import 'package:facetune/features/scan/domain/entities/local_image_validation.dart';
import 'package:facetune/features/scan/domain/entities/prepared_selfie.dart';
import 'package:facetune/features/scan/domain/entities/selfie_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/analysis_response_fixture.dart';

void main() {
  const selfie = PreparedSelfie(
    originalPath: 'original.jpg',
    uploadPath: 'upload.jpg',
    originalSizeBytes: 1000,
    uploadSizeBytes: 700,
    source: SelfieSource.gallery,
  );
  const localValidation = LocalImageValidation(
    mimeType: 'image/jpeg',
    width: 1080,
    height: 1440,
    originalSizeBytes: 1000,
    uploadSizeBytes: 700,
  );
  final analysis = FaceAnalysisDto.fromResponse(validAnalysisResponse).analysis;

  test('clear ignores a late analysis completion and progress update', () async {
    final pending = Completer<FaceAnalysis>();
    final repository = _FakeFaceAnalysisRepository(completer: pending);
    final controller = FaceAnalysisController(AnalyzeFace(repository));

    final operation = controller.analyze(
      selfie: selfie,
      localValidation: localValidation,
    );
    expect(controller.state.status, FaceAnalysisStatus.uploading);

    controller.clear();
    repository.emitProgress(AnalysisProgress.secureProcessing);
    pending.complete(analysis);
    await operation;

    expect(controller.state.status, FaceAnalysisStatus.idle);
    expect(controller.state.analysis, isNull);
  });

  test('restore is not overwritten by a prior late completion', () async {
    final pending = Completer<FaceAnalysis>();
    final repository = _FakeFaceAnalysisRepository(completer: pending);
    final controller = FaceAnalysisController(AnalyzeFace(repository));
    final lateAnalysis = FaceAnalysis(
      id: 'late-result',
      originalImagePath: analysis.originalImagePath,
      validation: analysis.validation,
      attributes: analysis.attributes,
      confidence: analysis.confidence,
      modelId: analysis.modelId,
      promptVersion: analysis.promptVersion,
      createdAt: analysis.createdAt,
    );

    final operation = controller.analyze(
      selfie: selfie,
      localValidation: localValidation,
    );
    controller.restore(analysis);
    pending.complete(lateAnalysis);
    await operation;

    expect(controller.state.status, FaceAnalysisStatus.success);
    expect(controller.state.analysis, same(analysis));
  });

  test('unexpected repository errors become safe retryable failures', () async {
    final repository = _FakeFaceAnalysisRepository(
      unexpectedFailure: StateError('database_password=do-not-expose'),
    );
    final controller = FaceAnalysisController(AnalyzeFace(repository));

    await controller.analyze(
      selfie: selfie,
      localValidation: localValidation,
    );

    expect(controller.state.status, FaceAnalysisStatus.serverFailure);
    expect(controller.state.retryable, isTrue);
    expect(controller.state.message, isNot(contains('database_password')));
  });
}

class _FakeFaceAnalysisRepository implements FaceAnalysisRepository {
  _FakeFaceAnalysisRepository({this.completer, this.unexpectedFailure});

  final Completer<FaceAnalysis>? completer;
  final Object? unexpectedFailure;
  void Function(AnalysisProgress progress)? _onProgress;

  void emitProgress(AnalysisProgress progress) => _onProgress?.call(progress);

  @override
  Future<FaceAnalysis> analyze({
    required PreparedSelfie selfie,
    required LocalImageValidation localValidation,
    required void Function(AnalysisProgress progress) onProgress,
  }) {
    _onProgress = onProgress;
    final failure = unexpectedFailure;
    if (failure != null) return Future<FaceAnalysis>.error(failure);
    return completer!.future;
  }
}
