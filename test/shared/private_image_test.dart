import 'package:facetune/shared/widgets/media/private_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _boxed({double? width, double? height}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        height: height,
        child: const PrivateImage(url: 'https://example.com/preview.jpg'),
      ),
    ),
  ),
);

ImageProvider _providerOf(WidgetTester tester) =>
    tester.widget<Image>(find.byType(Image)).image;

void main() {
  testWidgets('decodes a list thumbnail at layout size, not source size', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_boxed(width: 104, height: 132));

    // Longest side (132) x device pixel ratio (2). Decoding a 2048px source at
    // full resolution would cost roughly 25x more raster memory per tile.
    expect(
      _providerOf(tester),
      isA<ResizeImage>().having((provider) => provider.width, 'width', 264),
    );
  });

  testWidgets('scales the decode budget with device pixel ratio', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_boxed(width: 104, height: 132));

    expect(
      _providerOf(tester),
      isA<ResizeImage>().having((provider) => provider.width, 'width', 396),
    );
  });

  testWidgets('leaves an unbounded box at source resolution', (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: PrivateImage(url: 'https://example.com/preview.jpg'),
          ),
        ),
      ),
    );

    expect(_providerOf(tester), isNot(isA<ResizeImage>()));
  });
}
