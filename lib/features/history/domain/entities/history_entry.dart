import '../../../analysis/domain/entities/face_analysis.dart';
import '../../../makeup_styles/domain/entities/makeup_style.dart';
import '../../../preview/domain/entities/generated_preview.dart';
import '../../../recommendation/domain/entities/makeup_recommendation.dart';
import '../../../saved_looks/domain/entities/saved_look.dart';

enum HistoryCompletionStatus { analysisReady, recommendationReady, complete }

enum HistoryFilter { all, completed, favorites }

class HistoryEntry {
  const HistoryEntry({
    required this.analysis,
    required this.thumbnailUrl,
    required this.status,
    required this.createdAt,
    required this.latestActivityAt,
    this.recommendation,
    this.style,
    this.preview,
    this.savedLook,
  });

  final FaceAnalysis analysis;
  final MakeupRecommendation? recommendation;
  final MakeupStyle? style;
  final GeneratedPreview? preview;
  final SavedLook? savedLook;
  final String thumbnailUrl;
  final HistoryCompletionStatus status;
  final DateTime createdAt;
  final DateTime latestActivityAt;

  String get id => analysis.id;
  bool get isFavorite => savedLook?.isFavorite == true;
  bool get canRegenerate => recommendation != null && style != null;

  HistoryEntry copyWith({SavedLook? savedLook}) => HistoryEntry(
    analysis: analysis,
    recommendation: recommendation,
    style: style,
    preview: preview,
    savedLook: savedLook ?? this.savedLook,
    thumbnailUrl: thumbnailUrl,
    status: status,
    createdAt: createdAt,
    latestActivityAt: latestActivityAt,
  );
}

class HistoryPageResult {
  const HistoryPageResult({
    required this.items,
    required this.hasMore,
    required this.nextOffset,
  });

  final List<HistoryEntry> items;
  final bool hasMore;
  final int nextOffset;
}
