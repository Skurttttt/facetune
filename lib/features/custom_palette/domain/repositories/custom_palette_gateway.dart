import '../validation/custom_palette_contract.dart';

/// A generation request that could not be completed.
class CustomPaletteFailure implements Exception {
  const CustomPaletteFailure(this.message, {this.retryable = false});

  /// Safe to show to the user.
  final String message;
  final bool retryable;
}

/// The authenticated server path for a frozen palette.
///
/// The client hands over the canonical request and nothing else. It never
/// writes palette, recommendation or preview rows itself.
abstract interface class CustomPaletteGateway {
  /// Submits [request]. Throws [CustomPaletteFailure] when it cannot complete.
  Future<void> submit(CustomPaletteRequest request);
}
