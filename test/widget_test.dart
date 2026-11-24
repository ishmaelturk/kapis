import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapis/app.dart';
import 'package:kapis/application/app_preferences_controller.dart';
import 'package:kapis/domain/models/app_preferences.dart';
import 'package:kapis/domain/repositories/app_preferences_repository.dart';
import 'package:kapis/features/auth/presentation/auth_screen.dart';
import 'package:kapis/features/listings/presentation/listing_discovery_screen.dart';
import 'package:kapis/features/listings/presentation/listing_form_screen.dart';
import 'package:kapis/features/listings/presentation/my_listings_screen.dart';
import 'package:kapis/features/settings/presentation/accessibility_settings_screen.dart';
import 'package:kapis/features/settings/presentation/app_settings_screen.dart';
import 'package:kapis/features/settings/presentation/settings_screen.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('Discovery is the app index page', (WidgetTester tester) async {
    await tester.pumpWidget(_buildApp(_MemoryPreferencesRepository()));

    expect(find.byType(ListingDiscoveryScreen), findsOneWidget);
    expect(find.text('Yakınındaki bağışlar'), findsOneWidget);
    expect(find.text('Semt / mahalle'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('Navigation drawer shows all main destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildApp(_MemoryPreferencesRepository()));

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
      find.descendant(of: drawer, matching: find.text('Ayarlar')),
      findsOneWidget,
    );
  });

  for (final (label, destination) in <(String, Type)>[
    ('Bağışları keşfet', ListingDiscoveryScreen),
    ('Eşya bağışla', ListingFormScreen),
    ('Bağışlarım', MyListingsScreen),
    ('Ayarlar', SettingsScreen),
  ]) {
    testWidgets('Drawer opens $label', (WidgetTester tester) async {
      await tester.pumpWidget(_buildApp(_MemoryPreferencesRepository()));

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

  testWidgets('Settings overview puts account first and opens each page', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final preferences = _MemoryPreferencesRepository();
    await _openSettings(tester, preferences);

    expect(find.text('Hesap ayarları'), findsOneWidget);
    expect(find.text('Uygulama ayarları'), findsOneWidget);
    expect(find.text('Erişilebilirlik ayarları'), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(3));
    expect(
      tester.getTopLeft(find.text('Hesap ayarları')).dy,
      lessThan(tester.getTopLeft(find.text('Uygulama ayarları')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Uygulama ayarları')).dy,
      lessThan(tester.getTopLeft(find.text('Erişilebilirlik ayarları')).dy),
    );

    await tester.tap(find.text('Uygulama ayarları'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSettingsScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Erişilebilirlik ayarları'));
    await tester.pumpAndSettle();
    expect(find.byType(AccessibilitySettingsScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hesap ayarları'));
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
  });

  testWidgets('App settings persist and apply theme choices', (
    WidgetTester tester,
  ) async {
    final preferences = _MemoryPreferencesRepository();
    await _openSettings(tester, preferences);
    await tester.tap(find.text('Uygulama ayarları'));
    await tester.pumpAndSettle();

    for (final (label, mode) in <(String, AppThemeMode)>[
      ('Koyu', AppThemeMode.dark),
      ('Açık', AppThemeMode.light),
      ('Sistem', AppThemeMode.system),
    ]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(preferences.value.themeMode, mode);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        switch (mode) {
          AppThemeMode.system => ThemeMode.system,
          AppThemeMode.light => ThemeMode.light,
          AppThemeMode.dark => ThemeMode.dark,
        },
      );
    }
  });

  testWidgets('Accessibility settings apply and persist preferences', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final preferences = _MemoryPreferencesRepository();
    await _openSettings(tester, preferences);
    await tester.tap(find.text('Erişilebilirlik ayarları'));
    await tester.pumpAndSettle();

    final settingsFinder = find.byType(AccessibilitySettingsScreen);
    await tester.ensureVisible(find.text('Daha büyük'));
    final defaultTextSize = MediaQuery.of(tester.element(settingsFinder))
        .textScaler
        .scale(14);
    await tester.tap(find.text('Daha büyük'));
    await tester.pumpAndSettle();
    expect(
      preferences.value.accessibilityTextSize,
      AccessibilityTextSize.extraLarge,
    );
    expect(
      MediaQuery.of(tester.element(settingsFinder)).textScaler.scale(14),
      defaultTextSize * AccessibilityTextSize.extraLarge.scaleFactor,
    );

    await tester.ensureVisible(find.text('Yüksek karşıtlık'));
    final defaultPrimaryColor = Theme.of(tester.element(settingsFinder))
        .colorScheme
        .primary;
    await tester.tap(find.text('Yüksek karşıtlık'));
    await tester.pumpAndSettle();
    expect(preferences.value.highContrastEnabled, isTrue);
    expect(
      Theme.of(tester.element(settingsFinder)).colorScheme.primary,
      isNot(defaultPrimaryColor),
    );

    await tester.ensureVisible(find.text('Hareketleri azalt'));
    await tester.tap(find.text('Hareketleri azalt'));
    await tester.pumpAndSettle();
    expect(preferences.value.reduceMotion, isTrue);
    expect(
      MediaQuery.of(tester.element(settingsFinder)).disableAnimations,
      isTrue,
    );
    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .themeAnimationDuration,
      Duration.zero,
    );
  });

  testWidgets('Meets accessibility guidelines', (WidgetTester tester) async {
    await tester.pumpWidget(_buildApp(_MemoryPreferencesRepository()));

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });
}

Future<void> _openSettings(
  WidgetTester tester,
  _MemoryPreferencesRepository preferences,
) async {
  await tester.pumpWidget(_buildApp(preferences));
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ayarlar'));
  await tester.pumpAndSettle();
}

Widget _buildApp(_MemoryPreferencesRepository preferences) {
  return ProviderScope(
    overrides: [
      appPreferencesRepositoryProvider.overrideWithValue(preferences),
    ],
    child: const KapisApp(),
  );
}

final class _MemoryPreferencesRepository implements AppPreferencesRepository {
  AppPreferences value = const AppPreferences();

  @override
  Future<AppPreferences> load() async => value;

  @override
  Future<void> save(AppPreferences preferences) async {
    value = preferences;
  }
}
