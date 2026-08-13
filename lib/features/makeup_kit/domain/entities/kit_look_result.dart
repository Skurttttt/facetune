import '../../../analysis/domain/entities/face_analysis.dart';
import '../../../makeup_styles/domain/entities/makeup_style.dart';
import 'kit_generated_preview.dart';
import 'kit_makeup_recommendation.dart';

class KitLookResult {
  const KitLookResult({
    required this.analysis,
    required this.style,
    required this.recommendation,
    required this.preview,
  });

  final FaceAnalysis analysis;
  final MakeupStyle style;
  final KitMakeupRecommendation recommendation;
  final KitGeneratedPreview preview;
}

class KitSavedLook {
  const KitSavedLook({
    required this.id,
    required this.result,
    required this.isFavorite,
    required this.createdAt,
  });

  final String id;
  final KitLookResult result;
  final bool isFavorite;
  final DateTime createdAt;

  KitSavedLook copyWith({bool? isFavorite}) => KitSavedLook(
    id: id,
    result: result,
    isFavorite: isFavorite ?? this.isFavorite,
    createdAt: createdAt,
  );
}

class KitHistoryEntry {
  const KitHistoryEntry({required this.result, this.savedLook});

  final KitLookResult result;
  final KitSavedLook? savedLook;

  String get id => result.preview.id;
  bool get isFavorite => savedLook?.isFavorite == true;
}

class KitSavedLooksPageResult {
  const KitSavedLooksPageResult({required this.items, required this.hasMore});

  final List<KitSavedLook> items;
  final bool hasMore;
}

class KitHistoryPageResult {
  const KitHistoryPageResult({required this.items, required this.hasMore});

  final List<KitHistoryEntry> items;
  final bool hasMore;
}
