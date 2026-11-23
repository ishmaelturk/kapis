// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:kapis/app.dart';

void main() {
  testWidgets('shows the Kapış pick-up-only landing page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const KapisApp());

    expect(find.text('Kapış'), findsOneWidget);
    expect(
      find.text('Kullanılabilir eşyalar, yeni sahipleriyle buluşsun.'),
      findsOneWidget,
    );
    expect(find.text('Ücretsiz paylaş, yakından gel-al.'), findsOneWidget);
  });

  testWidgets('Meets accessibility guidelines', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const KapisApp());

    // Checks that tappable nodes have a minimum size of 48 by 48 pixels
    // for Android.
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

    // Checks that tappable nodes have a minimum size of 44 by 44 pixels
    // for iOS.
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

    // Checks that touch targets with a tap or long press action are labeled.
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    // Checks that text meets the minimum contrast ratio: 4.5:1 for normal
    // text and 3:1 for large text.
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });
}
