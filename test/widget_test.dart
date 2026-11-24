import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kapis/features/auth/presentation/auth_screen.dart';
import 'package:kapis/features/listings/presentation/listing_discovery_screen.dart';
import 'package:kapis/features/listings/presentation/listing_form_screen.dart';
import 'package:kapis/features/listings/presentation/my_listings_screen.dart';
import 'package:kapis/app.dart';

void main() {
  testWidgets('Kapış welcome screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: KapisApp()));

    expect(find.text('Kapış'), findsOneWidget);
    expect(
      find.text('Kullanılabilir eşyalar, yeni sahiplerini bekliyor.'),
      findsOneWidget,
    );
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('Navigation drawer shows all main destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: KapisApp()));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    final drawer = find.byType(Drawer);
    expect(drawer, findsOneWidget);
    expect(
      find.descendant(of: drawer, matching: find.text('Bağışları keşfet')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: drawer, matching: find.text('Eşya bağışla')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: drawer, matching: find.text('Bağışlarım')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: drawer,
        matching: find.text('Hesap / öğrenci rozeti'),
      ),
      findsOneWidget,
    );
  });

  for (final (label, destination) in <(String, Type)>[
    ('Bağışları keşfet', ListingDiscoveryScreen),
    ('Eşya bağışla', ListingFormScreen),
    ('Bağışlarım', MyListingsScreen),
    ('Hesap / öğrenci rozeti', AuthScreen),
  ]) {
    testWidgets('Drawer opens $label', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: KapisApp()));

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(Drawer), matching: find.text(label)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(destination), findsOneWidget);
      expect(find.byType(Drawer), findsNothing);
    });
  }

  testWidgets('Meets accessibility guidelines', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: KapisApp()));

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });
}
