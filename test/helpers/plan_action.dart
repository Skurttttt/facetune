import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The callback behind a plan card's action button, whatever its emphasis.
///
/// The paywall draws the recommended plan's action as a [PrimaryButton] and
/// every other plan's as a [SecondaryButton]. A test that cares whether a plan
/// is *buyable* should not also be pinning which of the two it is — that is a
/// hierarchy decision with its own tests — so this reads `onPressed` off either.
VoidCallback? planActionOf(WidgetTester tester, String plan) {
  final widget = tester.widget(find.byKey(ValueKey('plan-action-$plan')));
  return switch (widget) {
    PrimaryButton(:final onPressed) => onPressed,
    SecondaryButton(:final onPressed) => onPressed,
    _ => throw StateError(
      'plan-action-$plan is a ${widget.runtimeType}, not a shared button',
    ),
  };
}
