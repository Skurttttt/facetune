import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_generated_preview.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_look_result.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/makeup_kit/presentation/widgets/kit_saved_look_card.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/preview/domain/entities/generated_preview.dart';
import 'package:facetune/features/recommendation/data/models/makeup_recommendation_dto.dart';
import 'package:facetune/features/saved_looks/domain/entities/saved_look.dart';
import 'package:facetune/features/saved_looks/presentation/widgets/saved_look_card.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/analysis_response_fixture.dart';
import '../../helpers/recommendation_response_fixture.dart';

/// The Saved Looks library tile, from both authorities.
///
/// Both cards must say the same four things in the same order and the same
/// words, while each reads only its own mode's data — and the tile must carry
/// exactly one secondary control, not a badge over the photograph plus a button
/// underneath it.
void main() {
  group('Saved Makeup Recommendation card', () {
    testWidgets('shows title, mode, completion and a readable date', (
      tester,
    ) async {
      final look = _savedLook();
      await _pumpCard(tester, _standardCard(look));

      expect(find.text(look.style.name), findsOneWidget);
      expect(find.text('Recommendation'), findsOneWidget);
      expect(find.text('Complete'), findsOneWidget);

      // A library date, not a database one.
      final formatted = LookCardMetadata.formatSavedDate(
        tester.element(find.byType(LookCardMetadata)),
        look.createdAt,
      );
      expect(find.text(formatted), findsOneWidget);
      expect(formatted, contains('2026'));
      expect(find.text('2026-09-05'), findsNothing);
      expect(find.textContaining(RegExp(r'^\d{4}-\d{2}-\d{2}$')), findsNothing);
    });

    testWidgets('draws nothing over the photograph', (tester) async {
      await _pumpCard(tester, _standardCard(_savedLook(isFavorite: true)));

      // The white circle that used to carry the heart is gone, and no badge,
      // chip or second control replaced it.
      expect(find.byType(CircleAvatar), findsNothing);
      expect(find.text('MY KIT'), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.byIcon(Icons.bookmark_rounded), findsNothing);

      // Exactly one secondary control on the tile.
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
      expect(find.byType(LookCardActions), findsOneWidget);
    });

    testWidgets('marks a favourite beside the title, as History does', (
      tester,
    ) async {
      await _pumpCard(tester, _standardCard(_savedLook(isFavorite: true)));
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

      await _pumpCard(tester, _standardCard(_savedLook()));
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    });

    testWidgets('tapping the card opens the look', (tester) async {
      var opened = 0;
      await _pumpCard(
        tester,
        _standardCard(_savedLook(), onOpen: () => opened += 1),
      );

      await tester.tap(find.byType(PrivateImage));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });

    testWidgets('the overflow keeps favourite and remove, and adds no delete', (
      tester,
    ) async {
      var favorited = 0;
      var removed = 0;
      await _pumpCard(
        tester,
        _standardCard(
          _savedLook(),
          onFavorite: () => favorited += 1,
          onRemove: () => removed += 1,
        ),
      );

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Add favorite'), findsOneWidget);
      expect(find.text('Remove from saved'), findsOneWidget);
      // Saved has no delete capability, so the menu must not offer one.
      expect(find.text('Delete'), findsNothing);
      expect(find.textContaining('Delete'), findsNothing);

      await tester.tap(find.text('Remove from saved'));
      await tester.pumpAndSettle();
      expect(removed, 1);
      expect(favorited, 0);
    });

    testWidgets('a favourited look offers to remove the favourite', (
      tester,
    ) async {
      var favorited = 0;
      await _pumpCard(
        tester,
        _standardCard(
          _savedLook(isFavorite: true),
          onFavorite: () => favorited += 1,
        ),
      );

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Remove favorite'), findsOneWidget);

      await tester.tap(find.text('Remove favorite'));
      await tester.pumpAndSettle();
      expect(favorited, 1);
    });

    testWidgets('while mutating, the tile neither opens nor offers a menu', (
      tester,
    ) async {
      var opened = 0;
      await _pumpCard(
        tester,
        _standardCard(
          _savedLook(),
          isMutating: true,
          onOpen: () => opened += 1,
        ),
      );

      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
      expect(find.byType(AppProgress), findsOneWidget);
      await tester.tap(find.byType(PrivateImage));
      await tester.pump();
      expect(opened, 0);
    });
  });

  group('Saved My Makeup Kit card', () {
    testWidgets('shows title, mode, owned-product count and a date', (
      tester,
    ) async {
      final look = _kitSavedLook(products: 2);
      await _pumpCard(tester, _kitCard(look));

      expect(find.text(look.result.style.name), findsOneWidget);
      expect(find.text('My Makeup Kit'), findsOneWidget);
      expect(find.text('2 owned products'), findsOneWidget);

      final formatted = LookCardMetadata.formatSavedDate(
        tester.element(find.byType(LookCardMetadata)),
        look.createdAt,
      );
      expect(find.text(formatted), findsOneWidget);
    });

    testWidgets('counts one owned product in the singular', (tester) async {
      await _pumpCard(tester, _kitCard(_kitSavedLook(products: 1)));

      expect(find.text('1 owned product'), findsOneWidget);
      expect(find.text('1 owned products'), findsNothing);
    });

    testWidgets('draws nothing over the photograph', (tester) async {
      await _pumpCard(
        tester,
        _kitCard(_kitSavedLook(products: 1, isFavorite: true)),
      );

      // Both the heart badge and the pink "MY KIT" pill are gone from the
      // image; the mode is a footer line now.
      expect(find.byType(CircleAvatar), findsNothing);
      expect(find.text('MY KIT'), findsNothing);
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });

    testWidgets('the overflow keeps favourite and remove, and adds no delete', (
      tester,
    ) async {
      var removed = 0;
      await _pumpCard(
        tester,
        _kitCard(_kitSavedLook(products: 1), onRemove: () => removed += 1),
      );

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Add favorite'), findsOneWidget);
      expect(find.text('Remove from saved'), findsOneWidget);
      expect(find.textContaining('Delete'), findsNothing);

      await tester.tap(find.text('Remove from saved'));
      await tester.pumpAndSettle();
      expect(removed, 1);
    });
  });

  group('Saved card image', () {
    testWidgets('uses the feed placeholder, not a spinner per tile', (
      tester,
    ) async {
      for (final card in <Widget>[
        _standardCard(_savedLook()),
        _kitCard(_kitSavedLook(products: 1)),
      ]) {
        await _pumpCard(tester, card);

        final image = tester.widget<PrivateImage>(find.byType(PrivateImage));
        expect(image.placeholder, isA<ImageSkeleton>());
        expect(image.fadeIn, isTrue);

        // A grid of tickers is the thing being removed: no progress indicator
        // may be built for a loading tile.
        expect(find.byType(ImagePlaceholder), findsNothing);
        expect(find.byType(AppProgress), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      }
    });

    testWidgets('leaves the decode pipeline untouched', (tester) async {
      await _pumpCard(tester, _standardCard(_savedLook()));

      final image = tester.widget<PrivateImage>(find.byType(PrivateImage));
      // cacheWidth is derived inside PrivateImage from the layout box; the card
      // must not start overriding it.
      expect(image.decodeMultiplier, 1);
      expect(image.fit, BoxFit.cover);
      expect(image.url, contains('generated'));
    });

    testWidgets('the image fills the full tile width, leaving no side strip', (
      tester,
    ) async {
      for (final card in <Widget>[
        _standardCard(_savedLook()),
        _kitCard(_kitSavedLook(products: 1)),
      ]) {
        await _pumpCard(tester, card, width: 170, height: 304);

        final cardRect = tester.getRect(find.byType(Card));
        final imageRect = tester.getRect(find.byType(PrivateImage));

        // The regression: on a loose cross axis the image sized itself to its
        // own aspect ratio and left a strip down the right edge.
        expect(imageRect.width, cardRect.width);
        expect(imageRect.left, cardRect.left);
        expect(imageRect.right, cardRect.right);
      }
    });

    testWidgets('the footer keeps the same width as the image', (tester) async {
      await _pumpCard(tester, _standardCard(_savedLook()));

      final imageRect = tester.getRect(find.byType(PrivateImage));
      final footerRect = tester.getRect(find.byType(LookCardMetadata));

      expect(footerRect.width, imageRect.width);
      expect(footerRect.left, imageRect.left);
    });

    testWidgets('the card still renders its error ground when loading fails', (
      tester,
    ) async {
      await _pumpCard(tester, _standardCard(_savedLook()));
      // The test HTTP client answers every request with a 400, so a pumped
      // Image.network settles into its error state — which is what proves the
      // error path is still wired through PrivateImage.
      await tester.pumpAndSettle();

      expect(find.byType(ImageUnavailable), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Saved card parity', () {
    testWidgets('both modes use one footer in one vocabulary', (tester) async {
      await _pumpCard(tester, _standardCard(_savedLook()));
      final standardTitle = tester.widget<Text>(
        find.text(MakeupStyleCatalog.styles.first.name),
      );
      final standardMode = tester.widget<Text>(find.text('Recommendation'));
      final standardFooter = tester.getSize(find.byType(LookCardMetadata));

      await _pumpCard(tester, _kitCard(_kitSavedLook(products: 1)));
      final kitTitle = tester.widget<Text>(
        find.text(MakeupStyleCatalog.styles.first.name),
      );
      final kitMode = tester.widget<Text>(find.text('My Makeup Kit'));
      final kitFooter = tester.getSize(find.byType(LookCardMetadata));

      expect(kitTitle.style, standardTitle.style);
      expect(kitMode.style, standardMode.style);
      expect(kitFooter, standardFooter);
    });

    testWidgets('the tile survives a narrow column and doubled text', (
      tester,
    ) async {
      for (final card in <Widget>[
        _standardCard(_savedLook()),
        _kitCard(_kitSavedLook(products: 12)),
      ]) {
        await _pumpCard(tester, card, width: 150, height: 268, textScale: 2);
        expect(tester.takeException(), isNull);
      }
    });
  });
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Widget _standardCard(
  SavedLook look, {
  VoidCallback? onOpen,
  VoidCallback? onFavorite,
  VoidCallback? onRemove,
  bool isMutating = false,
}) => SavedLookCard(
  look: look,
  onOpen: onOpen ?? () {},
  onFavorite: onFavorite ?? () {},
  onRemove: onRemove ?? () {},
  isMutating: isMutating,
);

Widget _kitCard(
  KitSavedLook look, {
  VoidCallback? onOpen,
  VoidCallback? onFavorite,
  VoidCallback? onRemove,
  bool isMutating = false,
}) => KitSavedLookCard(
  look: look,
  isMutating: isMutating,
  onOpen: onOpen ?? () {},
  onFavorite: onFavorite ?? () {},
  onRemove: onRemove ?? () {},
);

/// One tile at the size the two-column grid gives it on a phone.
Future<void> _pumpCard(
  WidgetTester tester,
  Widget card, {
  double width = 170,
  double height = 304,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, height: height, child: card),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

final _analysis = FaceAnalysisDto.fromResponse(validAnalysisResponse).analysis;
final _style = MakeupStyleCatalog.styles.first;
final _savedAt = DateTime.utc(2026, 9, 5, 14, 3);

SavedLook _savedLook({bool isFavorite = false}) => SavedLook(
  id: 'saved-1',
  preview: GeneratedPreview(
    id: 'preview-1',
    analysisId: _analysis.id,
    recommendationId: 'recommendation-1',
    originalImageUrl: 'https://example.test/original.jpg',
    generatedImageUrl: 'https://example.test/generated.jpg',
    originalImagePath: 'user/original.jpg',
    generatedImagePath: 'user/generated.jpg',
    generationNumber: 1,
    modelId: 'gemini-3.1-flash-image',
    promptVersion: 'makeup_preview_v2',
    createdAt: _savedAt,
  ),
  analysis: _analysis,
  recommendation: MakeupRecommendationDto.fromResponse(
    validRecommendationResponse,
  ).recommendation,
  style: _style,
  isFavorite: isFavorite,
  createdAt: _savedAt,
);

KitSavedLook _kitSavedLook({required int products, bool isFavorite = false}) =>
    KitSavedLook(
      id: 'kit-saved-1',
      isFavorite: isFavorite,
      createdAt: _savedAt,
      result: KitLookResult(
        analysis: _analysis,
        style: _style,
        recommendation: KitMakeupRecommendation(
          id: 'kit-recommendation-1',
          analysisId: _analysis.id,
          styleCode: _style.code,
          selections: <KitMakeupSelection>[
            for (var index = 0; index < products; index++)
              KitMakeupSelection(
                productId: 'product-$index',
                category: 'lipstick',
                colorHex: '#B86F72',
                finish: 'matte',
                placement: 'Across the lips',
                technique: 'Apply a thin layer',
                intensity: 'soft',
              ),
          ],
          productSnapshots: <KitProductSnapshot>[
            for (var index = 0; index < products; index++)
              KitProductSnapshot(
                productId: 'product-$index',
                category: 'lipstick',
                colorHex: '#B86F72',
                finish: 'matte',
                productName: 'My lipstick $index',
                colorLabel: 'Warm Rose',
              ),
          ],
          overallIntensity: 'soft',
          summary: 'Built from owned products.',
          modelId: 'test-model',
          promptVersion: 'test-prompt',
          createdAt: _savedAt,
        ),
        preview: KitGeneratedPreview(
          id: 'kit-preview-1',
          analysisId: _analysis.id,
          kitRecommendationId: 'kit-recommendation-1',
          originalImageUrl: 'https://example.test/original.jpg',
          generatedImageUrl: 'https://example.test/generated.jpg',
          originalImagePath: 'user/original.jpg',
          generatedImagePath: 'user/kit-generated.jpg',
          generationNumber: 1,
          modelId: 'gemini-3.1-flash-image',
          promptVersion: 'kit_preview_v1',
          createdAt: _savedAt,
        ),
      ),
    );
