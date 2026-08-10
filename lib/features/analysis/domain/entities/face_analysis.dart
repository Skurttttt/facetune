import 'analysis_confidence.dart';
import 'facial_attributes.dart';
import 'secure_image_validation.dart';

class FaceAnalysis {
  const FaceAnalysis({
    required this.id,
    required this.originalImagePath,
    required this.validation,
    required this.attributes,
    required this.confidence,
    required this.modelId,
    required this.promptVersion,
    required this.createdAt,
  });

  final String id;
  final String originalImagePath;
  final SecureImageValidation validation;
  final FacialAttributes attributes;
  final AnalysisConfidence confidence;
  final String modelId;
  final String promptVersion;
  final DateTime createdAt;
}
