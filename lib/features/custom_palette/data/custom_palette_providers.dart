import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/custom_palette_gateway.dart';
import '../domain/validation/custom_palette_contract.dart';

/// Refuses every request: the server path arrives with CCP-4.
class UnavailableCustomPaletteGateway implements CustomPaletteGateway {
  const UnavailableCustomPaletteGateway();

  @override
  Future<void> submit(CustomPaletteRequest request) async {
    throw const CustomPaletteFailure(
      'Custom Color Palette looks are not available in this build yet.',
    );
  }
}

final customPaletteGatewayProvider = Provider<CustomPaletteGateway>(
  (ref) => const UnavailableCustomPaletteGateway(),
);
