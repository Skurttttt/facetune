import '../../../makeup_kit/domain/entities/makeup_kit_category.dart';
import '../../../makeup_kit/domain/entities/makeup_kit_finish.dart';
import '../catalog/custom_palette_catalog.dart';

/// The validation vocabulary of the canonical palette contract (CCP-1).
///
/// [code] is shared with the server, which enforces the same rules
/// independently. Neither side ever repairs an invalid palette: it refuses it.
enum CustomPaletteIssueCode {
  paletteEmpty('palette_empty'),
  selectionIncomplete('selection_incomplete'),
  invalidColor('invalid_color'),
  invalidBaseColor('invalid_base_color'),
  unsupportedCategory('unsupported_category'),
  unsupportedFinish('unsupported_finish'),
  finishNotApplicable('finish_not_applicable'),
  duplicateCategory('duplicate_category');

  const CustomPaletteIssueCode(this.code);

  final String code;
}

class CustomPaletteIssue {
  const CustomPaletteIssue(this.code, {this.categoryCode});

  final CustomPaletteIssueCode code;

  /// The category at fault; `null` for a palette-wide issue.
  final String? categoryCode;

  @override
  bool operator ==(Object other) =>
      other is CustomPaletteIssue &&
      other.code == code &&
      other.categoryCode == categoryCode;

  @override
  int get hashCode => Object.hash(code, categoryCode);

  @override
  String toString() => '${code.code}(${categoryCode ?? 'palette'})';
}

/// One enabled category, as untyped wire values, so the validator can judge a
/// malformed value rather than being unable to represent one.
class CustomPaletteSelectionInput {
  const CustomPaletteSelectionInput({
    required this.categoryCode,
    this.baseColorValue,
    this.adjustedColorValue,
    this.colorLabel,
    this.finishCode,
  });

  final String categoryCode;
  final String? baseColorValue;
  final String? adjustedColorValue;
  final String? colorLabel;
  final String? finishCode;

  Map<String, Object?> toJson() => {
    'categoryCode': categoryCode,
    'baseColorValue': baseColorValue,
    'adjustedColorValue': adjustedColorValue,
    'colorLabel': colorLabel,
    'finishCode': finishCode,
  };
}

abstract final class CustomPaletteValidator {
  // Canonical form only: the same shape the database and the Standard
  // recommendation contract use. Lowercase is malformed here, not normalized.
  static final RegExp _canonicalHex = RegExp(r'^#[0-9A-F]{6}$');

  /// Every way [selections] breaks the contract; empty when it is valid.
  static List<CustomPaletteIssue> validate(
    List<CustomPaletteSelectionInput> selections,
  ) {
    if (selections.isEmpty) {
      return const [CustomPaletteIssue(CustomPaletteIssueCode.paletteEmpty)];
    }
    final issues = <CustomPaletteIssue>[];
    final seen = <String>{};
    for (final selection in selections) {
      final code = selection.categoryCode;
      if (!seen.add(code)) {
        issues.add(
          CustomPaletteIssue(
            CustomPaletteIssueCode.duplicateCategory,
            categoryCode: code,
          ),
        );
        continue;
      }
      final category = MakeupKitCategory.fromCode(code);
      if (category == null || !CustomPaletteCatalog.isSupported(category)) {
        issues.add(
          CustomPaletteIssue(
            CustomPaletteIssueCode.unsupportedCategory,
            categoryCode: code,
          ),
        );
        continue;
      }
      issues.addAll(_validateSelection(category, selection));
    }
    return List.unmodifiable(issues);
  }

  static List<CustomPaletteIssue> _validateSelection(
    MakeupKitCategory category,
    CustomPaletteSelectionInput selection,
  ) {
    CustomPaletteIssue issue(CustomPaletteIssueCode code) =>
        CustomPaletteIssue(code, categoryCode: category.code);

    final base = selection.baseColorValue;
    final adjusted = selection.adjustedColorValue;
    final finish = selection.finishCode;
    if (base == null || adjusted == null || finish == null) {
      return [issue(CustomPaletteIssueCode.selectionIncomplete)];
    }

    final issues = <CustomPaletteIssue>[];
    if (!_canonicalHex.hasMatch(base) || !_canonicalHex.hasMatch(adjusted)) {
      issues.add(issue(CustomPaletteIssueCode.invalidColor));
    } else {
      final swatch = CustomPaletteCatalog.swatchFor(base);
      if (swatch == null || swatch.label != selection.colorLabel) {
        issues.add(issue(CustomPaletteIssueCode.invalidBaseColor));
      }
    }

    final parsedFinish = MakeupKitFinish.fromCode(finish);
    if (parsedFinish == null) {
      issues.add(issue(CustomPaletteIssueCode.unsupportedFinish));
    } else if (!CustomPaletteCatalog.finishesFor(
      category,
    ).contains(parsedFinish)) {
      issues.add(issue(CustomPaletteIssueCode.finishNotApplicable));
    }
    return issues;
  }

  /// [selections] in canonical category order.
  static List<CustomPaletteSelectionInput> canonicalOrder(
    Iterable<CustomPaletteSelectionInput> selections,
  ) {
    int rank(CustomPaletteSelectionInput selection) {
      final category = MakeupKitCategory.fromCode(selection.categoryCode);
      final index = category == null
          ? -1
          : CustomPaletteCatalog.categories.indexOf(category);
      return index < 0 ? CustomPaletteCatalog.categories.length : index;
    }

    return List.unmodifiable(
      selections.toList()..sort((a, b) => rank(a).compareTo(rank(b))),
    );
  }
}

/// The canonical request a valid draft produces.
///
/// It carries no user id: ownership comes from the JWT on the server, never
/// from the client. The server freezes this into the immutable palette.
class CustomPaletteRequest {
  const CustomPaletteRequest({
    required this.paletteRequestId,
    required this.analysisId,
    required this.styleCode,
    required this.selections,
    this.derivedFromPaletteId,
  });

  /// Stable across retries of one request, so a replay cannot create a second
  /// palette. A new id is issued only after the draft changes.
  final String paletteRequestId;
  final String analysisId;
  final String styleCode;
  final String? derivedFromPaletteId;

  /// In canonical category order.
  final List<CustomPaletteSelectionInput> selections;

  Map<String, Object?> toJson() => {
    'paletteRequestId': paletteRequestId,
    'paletteVersion': customColorPaletteContractVersion,
    'sourceMode': customColorPaletteSourceMode,
    'analysisId': analysisId,
    'style': styleCode,
    'derivedFromPaletteId': derivedFromPaletteId,
    'categorySelections': [
      for (final selection in selections) selection.toJson(),
    ],
  };
}
