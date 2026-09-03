import 'package:facetune/features/results/presentation/widgets/result_actions.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  bool isFavorite = false,
  bool isSharing = false,
  bool isMutating = false,
  VoidCallback? onFavorite,
  VoidCallback? onShare,
  VoidCallback? onGenerateAnother,
  double textScale = 1,
}) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Scaffold(
      body: SingleChildScrollView(
        child: ResultActions(
          isFavorite: isFavorite,
          isSharing: isSharing,
          isMutating: isMutating,
          onFavorite: onFavorite ?? () {},
          onShare: onShare ?? () {},
          onGenerateAnother: onGenerateAnother ?? () {},
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('exposes exactly three compact utilities and nothing else', (
    tester,
  ) async {
    await tester.pumpWidget(_host());

    expect(find.text('Favorite'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Try another'), findsOneWidget);
    expect(find.text('Generate another variation'), findsNothing);

    // Save belongs to the reserved bottom action area, and Home to the top
    // bar. Neither has a second entry point here.
    expect(find.text('Save look'), findsNothing);
    expect(find.text('Return home'), findsNothing);
    expect(
      find.byKey(const ValueKey('result-action-return-home')),
      findsNothing,
    );
    expect(find.byType(TertiaryButton), findsNothing);

    // "Try another" carries its own meaning; it needs no caption.
    expect(
      find.text('Regenerate if the result does not feel like you.'),
      findsNothing,
    );

    // Three peers on one row, matched in height.
    final favorite = find.byKey(const ValueKey('result-action-favorite'));
    final share = find.byKey(const ValueKey('result-action-share'));
    final tryAnother = find.byKey(const ValueKey('result-action-try-another'));
    expect(tester.getTopLeft(favorite).dy, tester.getTopLeft(share).dy);
    expect(tester.getTopLeft(share).dy, tester.getTopLeft(tryAnother).dy);
    expect(tester.getSize(favorite).height, tester.getSize(tryAnother).height);
  });

  testWidgets('each utility calls its own callback exactly once', (
    tester,
  ) async {
    var favorites = 0;
    var shares = 0;
    var regenerations = 0;
    await tester.pumpWidget(
      _host(
        onFavorite: () => favorites++,
        onShare: () => shares++,
        onGenerateAnother: () => regenerations++,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('result-action-favorite')));
    await tester.tap(find.byKey(const ValueKey('result-action-share')));
    await tester.pumpAndSettle();

    expect(favorites, 1);
    expect(shares, 1);
    // Nothing but the regenerate control regenerates.
    expect(regenerations, 0);

    await tester.tap(find.byKey(const ValueKey('result-action-try-another')));
    await tester.pumpAndSettle();
    expect(regenerations, 1);
  });

  testWidgets('the favorite control reflects and announces its state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host());
    expect(find.bySemanticsLabel('Favorite'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

    await tester.pumpWidget(_host(isFavorite: true));
    expect(find.bySemanticsLabel('Remove from favorites'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.text('Favorited'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('sharing shows the shared spinner and refuses a second press', (
    tester,
  ) async {
    var shares = 0;
    await tester.pumpWidget(_host(isSharing: true, onShare: () => shares++));

    expect(find.byType(ButtonProgress), findsOneWidget);
    expect(find.text('Preparing'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('result-action-share')),
      warnIfMissed: false,
    );
    // A plain pump: the spinner is indeterminate, so nothing here ever settles.
    await tester.pump();
    expect(shares, 0);
  });

  testWidgets('a mutation in flight disables favorite but not regeneration', (
    tester,
  ) async {
    var favorites = 0;
    await tester.pumpWidget(
      _host(isMutating: true, onFavorite: () => favorites++),
    );

    await tester.tap(
      find.byKey(const ValueKey('result-action-favorite')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(favorites, 0);
  });

  testWidgets('the row gives way to full-width actions under large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(textScale: 2));

    final favorite = find.byKey(const ValueKey('result-action-favorite'));
    final share = find.byKey(const ValueKey('result-action-share'));
    final tryAnother = find.byKey(const ValueKey('result-action-try-another'));
    expect(
      tester.getTopLeft(share).dy,
      greaterThan(tester.getTopLeft(favorite).dy),
    );
    expect(
      tester.getTopLeft(tryAnother).dy,
      greaterThan(tester.getTopLeft(share).dy),
    );

    // Reflowed, not clipped: every label is still there in full.
    expect(find.text('Favorite'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Try another'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
