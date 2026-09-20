import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scrolls the paywall's lazy list until [target] is built and visible.
///
/// The paywall lists eight plans across three sections, so anything past the
/// first few cards is below the fold of the test viewport and, being lazily
/// built, does not exist until the list is scrolled. Reaching it the way a
/// user would is also the honest way to test it.
Future<void> revealOnPaywall(WidgetTester tester, Finder target) async {
  if (target.evaluate().isNotEmpty) return;
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// The callback behind a plan card's action button, whatever its emphasis.
///
/// The paywall draws the recommended plan's action as a [PrimaryButton] and
/// every other plan's as a [SecondaryButton]. A test that cares whether a plan
/// is *buyable* should not also be pinning which of the two it is — that is a
/// hierarchy decision with its own tests — so this reads `onPressed` off either.
///
/// Scrolls the card into the build window first; see [revealOnPaywall].
Future<VoidCallback?> planActionOf(WidgetTester tester, String plan) async {
  final finder = find.byKey(ValueKey('plan-action-$plan'));
  await revealOnPaywall(tester, finder);
  final widget = tester.widget(finder);
  return switch (widget) {
    PrimaryButton(:final onPressed) => onPressed,
    SecondaryButton(:final onPressed) => onPressed,
    _ => throw StateError(
      'plan-action-$plan is a ${widget.runtimeType}, not a shared button',
    ),
  };
}
