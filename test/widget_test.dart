import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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

  testWidgets('Meets accessibility guidelines', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: KapisApp()));

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });
}
