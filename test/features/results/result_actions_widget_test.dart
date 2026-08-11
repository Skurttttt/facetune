import 'package:facetune/features/results/presentation/widgets/result_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('exposes all required result actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResultActions(
            isSaved: false,
            isFavorite: false,
            isSharing: false,
            onSave: () {},
            onFavorite: () {},
            onShare: () {},
            onGenerateAnother: () {},
            onReturnHome: () {},
          ),
        ),
      ),
    );

    expect(find.text('Save look'), findsOneWidget);
    expect(find.text('Favorite'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Generate another variation'), findsOneWidget);
    expect(find.text('Return home'), findsOneWidget);
  });
}
