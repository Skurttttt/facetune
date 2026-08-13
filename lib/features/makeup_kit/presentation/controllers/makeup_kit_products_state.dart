import '../../domain/entities/makeup_kit_category.dart';
import '../../domain/entities/makeup_kit_product.dart';

enum MakeupKitProductsStatus { loading, ready, failure }

class MakeupKitProductsState {
  const MakeupKitProductsState({
    this.status = MakeupKitProductsStatus.loading,
    this.items = const [],
    this.isCreating = false,
    this.mutatingIds = const {},
    this.message,
    this.feedback,
    this.feedbackIsError = false,
    this.sessionExpired = false,
  });

  final MakeupKitProductsStatus status;
  final List<MakeupKitProduct> items;
  final bool isCreating;
  final Set<String> mutatingIds;
  final String? message;
  final String? feedback;
  final bool feedbackIsError;
  final bool sessionExpired;

  List<MakeupKitProduct> byCategory(MakeupKitCategory category) => items
      .where((product) => product.category == category)
      .toList(growable: false);
}
