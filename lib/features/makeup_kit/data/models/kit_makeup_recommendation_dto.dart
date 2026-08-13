import '../../domain/entities/kit_makeup_recommendation.dart';

class KitMakeupRecommendationDto {
  const KitMakeupRecommendationDto(this.recommendation);

  final KitMakeupRecommendation recommendation;

  factory KitMakeupRecommendationDto.fromResponse(Object? payload) {
    final root = _object(payload, 'response');
    final data = _object(root['recommendation'], 'recommendation');
    final plan = _object(data['plan'], 'plan');
    final selectionValues = plan['selections'];
    if (selectionValues is! List || selectionValues.isEmpty) {
      throw const FormatException('selections must be a non-empty list.');
    }
    final selections = selectionValues
        .map((value) {
          final item = _object(value, 'selection');
          final colorHex = _string(item, 'colorHex');
          if (!RegExp(r'^#[0-9A-F]{6}$').hasMatch(colorHex)) {
            throw const FormatException('colorHex is invalid.');
          }
          return KitMakeupSelection(
            productId: _string(item, 'productId'),
            category: _string(item, 'category'),
            colorHex: colorHex,
            finish: _string(item, 'finish'),
            placement: _string(item, 'placement'),
            technique: _string(item, 'technique'),
            intensity: _string(item, 'intensity'),
          );
        })
        .toList(growable: false);
    final snapshotValues = data['productSnapshot'];
    if (snapshotValues is! List || snapshotValues.isEmpty) {
      throw const FormatException('productSnapshot must be a non-empty list.');
    }
    final snapshots = snapshotValues
        .map((value) {
          final item = _object(value, 'productSnapshot item');
          final colorHex = _string(item, 'colorHex');
          if (!RegExp(r'^#[0-9A-F]{6}$').hasMatch(colorHex)) {
            throw const FormatException('snapshot colorHex is invalid.');
          }
          return KitProductSnapshot(
            productId: _string(item, 'productId'),
            category: _string(item, 'category'),
            productName: _nullableString(item['productName']),
            colorHex: colorHex,
            colorLabel: _nullableString(item['colorLabel']),
            finish: _string(item, 'finish'),
            foundationDepth: _nullableString(item['foundationDepth']),
            foundationUndertone: _nullableString(item['foundationUndertone']),
          );
        })
        .toList(growable: false);
    final snapshotIds = snapshots.map((item) => item.productId).toSet();
    if (snapshotIds.length != snapshots.length ||
        selections.any((item) => !snapshotIds.contains(item.productId))) {
      throw const FormatException('Product snapshot linkage is invalid.');
    }
    return KitMakeupRecommendationDto(
      KitMakeupRecommendation(
        id: _string(data, 'id'),
        analysisId: _string(data, 'analysisId'),
        styleCode: _string(data, 'style'),
        selections: List.unmodifiable(selections),
        productSnapshots: List.unmodifiable(snapshots),
        overallIntensity: _string(plan, 'overallIntensity'),
        summary: _string(plan, 'summary'),
        modelId: _string(data, 'modelId'),
        promptVersion: _string(data, 'promptVersion'),
        createdAt: DateTime.parse(_string(data, 'createdAt')).toUtc(),
      ),
    );
  }

  static Map<String, Object?> _object(Object? value, String name) {
    if (value is! Map) throw FormatException('$name must be an object.');
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static String _string(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a non-empty string.');
    }
    return value.trim();
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    if (value is! String) throw const FormatException('Expected text.');
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
