import 'package:facetune/admin/shared/admin_cards.dart';
import 'package:facetune/admin/theme/admin_theme.dart';
import 'package:facetune/admin/theme/admin_tokens.dart';
import 'package:facetune/admin/theme/admin_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AdminTheme.dark,
      darkTheme: AdminTheme.dark,
      themeMode: ThemeMode.dark,
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('AdminCard owns the canonical structural surface', (
    tester,
  ) async {
    await pumpCard(
      tester,
      const AdminCard(key: Key('card'), child: Text('Content')),
    );

    final decoration =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byKey(const Key('card')),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    final padding = tester.widget<Padding>(
      find.descendant(
        of: find.byKey(const Key('card')),
        matching: find.byType(Padding),
      ),
    );

    expect(decoration.color, AdminColors.surface);
    expect(decoration.border, Border.all(color: AdminColors.border));
    expect(decoration.borderRadius, BorderRadius.circular(AdminRadii.card));
    expect(decoration.boxShadow, isNull);
    expect(padding.padding, const EdgeInsets.all(AdminSpacing.ml));
  });

  testWidgets('AdminStatCard uses compact canonical statistic hierarchy', (
    tester,
  ) async {
    await pumpCard(
      tester,
      const AdminStatCard(
        key: Key('stat'),
        label: 'Total Users',
        value: '42',
        metadata: 'Authoritative accounts',
        icon: Icons.people_outline,
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('stat'))).width,
      greaterThanOrEqualTo(220),
    );
    expect(
      tester.widget<Text>(find.text('Total Users')).style,
      AdminTypography.cardTitle,
    );
    expect(
      tester.widget<Text>(find.text('42')).style?.fontSize,
      AdminTypography.metricValue.fontSize,
    );
    expect(
      tester.widget<Text>(find.text('Authoritative accounts')).style,
      AdminTypography.metadata,
    );
    expect(find.byType(AdminCard), findsOneWidget);
  });

  testWidgets('AdminChartCard keeps title description plot footer hierarchy', (
    tester,
  ) async {
    await pumpCard(
      tester,
      const SizedBox(
        width: 600,
        child: AdminChartCard(
          title: 'Usage Outcomes',
          description: 'Current month · Operations',
          trailing: Text('Window'),
          footer: Text('Legend'),
          child: SizedBox(key: Key('plot'), height: 120),
        ),
      ),
    );

    expect(find.byType(AdminCard), findsOneWidget);
    expect(find.byKey(const Key('plot')), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Usage Outcomes')).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('plot'))).dy),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('plot'))).dy,
      lessThan(tester.getTopLeft(find.text('Legend')).dy),
    );
  });
}
