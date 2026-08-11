import 'package:facetune/shared/widgets/feedback/loading_state.dart';
import 'package:facetune/shared/widgets/feedback/status_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('LoadingState uses readable copy and progress semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LoadingState(
            supportingText: 'You can safely go back while this finishes.',
            progress: .5,
          ),
        ),
      ),
    );

    expect(find.text('Creating your look…'), findsOneWidget);
    expect(
      find.text('You can safely go back while this finishes.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('StatusState exposes primary and secondary recovery actions', (
    tester,
  ) async {
    var retried = false;
    var returned = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatusState(
            title: 'Could not load',
            message: 'Check your connection and try again.',
            actionLabel: 'Retry',
            onAction: () => retried = true,
            secondaryActionLabel: 'Return',
            onSecondaryAction: () => returned = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Retry'));
    await tester.tap(find.text('Return'));

    expect(retried, isTrue);
    expect(returned, isTrue);
  });
}
