import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:facetune/app/app.dart';

void main() {
  testWidgets('FaceTune app bootstraps with the premium home', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FaceTuneApp()));

    expect(find.text('Good morning, Mia'), findsOneWidget);
    expect(find.text('Start Scan'), findsOneWidget);
    expect(find.text('Recent looks'), findsOneWidget);
  });
}
