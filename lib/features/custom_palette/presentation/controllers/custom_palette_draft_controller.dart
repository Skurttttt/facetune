import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../makeup_kit/domain/entities/makeup_kit_category.dart';
import '../../../makeup_kit/domain/entities/makeup_kit_finish.dart';
import '../../data/custom_palette_providers.dart';
import '../../domain/catalog/custom_palette_catalog.dart';
import '../../domain/catalog/custom_palette_color_model.dart';
import '../../domain/entities/custom_palette_look.dart';
import '../../domain/repositories/custom_palette_gateway.dart';
import '../../domain/validation/custom_palette_contract.dart';
import 'custom_palette_draft_state.dart';

final customPaletteDraftControllerProvider =
    StateNotifierProvider<
      CustomPaletteDraftController,
      CustomPaletteDraftState
    >((ref) {
      ref.watch(authControllerProvider.select((state) => state.user?.id));
      return CustomPaletteDraftController(
        ref.watch(customPaletteGatewayProvider),
      );
    });

/// Owns the one in-progress palette.
///
/// It lives in memory, like the analysis and style it belongs to: when the
/// process dies all three are gone together and the journey restarts from its
/// existing "not ready" state.
class CustomPaletteDraftController
    extends StateNotifier<CustomPaletteDraftState> {
  CustomPaletteDraftController(this._gateway, {String Function()? newId})
    : _newId = newId ?? const Uuid().v4,
      super(const CustomPaletteDraftState());

  final CustomPaletteGateway _gateway;
  final String Function() _newId;
  int _operationEpoch = 0;

  /// Readies the draft for [analysisId] and [styleCode].
  ///
  /// The same pair keeps the draft, so leaving and returning loses nothing. A
  /// different pair resets it, because a palette belongs to one look request.
  void prepareFor({required String analysisId, required String styleCode}) {
    if (state.analysisId == analysisId && state.styleCode == styleCode) return;
    _operationEpoch += 1;
    state = CustomPaletteDraftState(
      analysisId: analysisId,
      styleCode: styleCode,
    );
  }

  /// Starts a new draft from a generated look's frozen palette.
  ///
  /// The look is not touched and never can be: generating from this draft makes a
  /// new palette, linked back through [CustomPaletteDraftState.derivedFromPaletteId].
  /// Every value comes from the look's own record, not from catalog defaults.
  void startFromLook(CustomPaletteRecommendation look) {
    _operationEpoch += 1;
    state = CustomPaletteDraftState(
      analysisId: look.analysisId,
      styleCode: look.styleCode,
      derivedFromPaletteId: look.id,
      selections: {
        for (final shade in look.palette)
          shade.category: () {
            final position = CustomPaletteColorModel.toHsl(shade.adjustedColor);
            return CustomPaletteDraftSelection(
              enabled: true,
              base: CustomPaletteSwatch(
                shade.colorLabel,
                shade.baseColor.value,
              ),
              saturation: position.saturation,
              lightness: position.lightness,
              finish: shade.finish,
              restoredColor: shade.adjustedColor,
            );
          }(),
      },
    );
  }

  void setEnabled(MakeupKitCategory category, {required bool enabled}) {
    _edit(category, (selection) => selection.copyWith(enabled: enabled));
  }

  /// Chooses a base color, which also starts the adjuster from that color.
  void selectSwatch(MakeupKitCategory category, CustomPaletteSwatch swatch) {
    final position = CustomPaletteColorModel.toHsl(swatch.color);
    _edit(
      category,
      (selection) => selection.copyWith(
        enabled: true,
        base: swatch,
        saturation: position.saturation,
        lightness: position.lightness,
        clearRestoredColor: true,
      ),
    );
  }

  void setSaturation(MakeupKitCategory category, int saturation) {
    if (state.selectionFor(category).base == null) return;
    _edit(
      category,
      (selection) => selection.copyWith(
        saturation: saturation.clamp(0, 100),
        clearRestoredColor: true,
      ),
    );
  }

  void setLightness(MakeupKitCategory category, int lightness) {
    if (state.selectionFor(category).base == null) return;
    _edit(
      category,
      (selection) => selection.copyWith(
        lightness: lightness.clamp(0, 100),
        clearRestoredColor: true,
      ),
    );
  }

  /// Returns the final color to the base swatch.
  void resetAdjustment(MakeupKitCategory category) {
    final base = state.selectionFor(category).base;
    if (base != null) selectSwatch(category, base);
  }

  /// Refuses a finish the category does not allow, so the editor can never put
  /// a nonsensical combination into the draft.
  void selectFinish(MakeupKitCategory category, MakeupKitFinish finish) {
    if (!CustomPaletteCatalog.finishesFor(category).contains(finish)) return;
    _edit(
      category,
      (selection) => selection.copyWith(enabled: true, finish: finish),
    );
  }

  /// Submits the draft's canonical request.
  ///
  /// Ignored while a request is in flight or already succeeded, and refused
  /// while the draft is invalid. A retry reuses the same request id; only an
  /// edit issues a new one, so a double tap or a retry is one logical request.
  Future<void> generate() async {
    final analysisId = state.analysisId;
    final styleCode = state.styleCode;
    if (state.isSubmitting ||
        state.status == CustomPaletteDraftStatus.submitted ||
        analysisId == null ||
        styleCode == null ||
        !state.isValid) {
      return;
    }
    final requestId = state.paletteRequestId ?? _newId();
    final operation = ++_operationEpoch;
    state = _copy(
      status: CustomPaletteDraftStatus.submitting,
      paletteRequestId: requestId,
    );
    try {
      final recommendation = await _gateway.submit(
        CustomPaletteRequest(
          paletteRequestId: requestId,
          analysisId: analysisId,
          styleCode: styleCode,
          derivedFromPaletteId: state.derivedFromPaletteId,
          selections: CustomPaletteValidator.canonicalOrder(state.inputs),
        ),
      );
      if (mounted && operation == _operationEpoch) {
        state = _copy(
          status: CustomPaletteDraftStatus.submitted,
          paletteRequestId: requestId,
          recommendation: recommendation,
        );
      }
    } on CustomPaletteFailure catch (failure) {
      _fail(
        requestId,
        operation,
        failure.message,
        retryable: failure.retryable,
      );
    } catch (_) {
      _fail(
        requestId,
        operation,
        'Your look could not be created. Please try again.',
        retryable: true,
      );
    }
  }

  void _fail(
    String requestId,
    int operation,
    String message, {
    required bool retryable,
  }) {
    if (!mounted || operation != _operationEpoch) return;
    state = _copy(
      status: CustomPaletteDraftStatus.failed,
      paletteRequestId: requestId,
      message: message,
      retryable: retryable,
    );
  }

  void _edit(
    MakeupKitCategory category,
    CustomPaletteDraftSelection Function(CustomPaletteDraftSelection) change,
  ) {
    if (state.isSubmitting) return;
    state = _copy(
      selections: {
        ...state.selections,
        category: change(state.selectionFor(category)),
      },
    );
  }

  /// Everything not named falls back to an editing state with no request id,
  /// which is what makes any edit start a new logical request.
  CustomPaletteDraftState _copy({
    Map<MakeupKitCategory, CustomPaletteDraftSelection>? selections,
    CustomPaletteDraftStatus status = CustomPaletteDraftStatus.editing,
    String? paletteRequestId,
    CustomPaletteRecommendation? recommendation,
    String? message,
    bool retryable = false,
  }) => CustomPaletteDraftState(
    analysisId: state.analysisId,
    styleCode: state.styleCode,
    selections: selections ?? state.selections,
    status: status,
    paletteRequestId: paletteRequestId,
    derivedFromPaletteId: state.derivedFromPaletteId,
    recommendation: recommendation,
    message: message,
    retryable: retryable,
  );
}
