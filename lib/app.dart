import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'application/app_preferences_controller.dart';
import 'domain/models/app_preferences.dart';
import 'features/listings/presentation/listing_discovery_screen.dart';

class KapisApp extends ConsumerWidget {
  const KapisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref
        .watch(appPreferencesProvider)
        .when(
          data: (value) => value,
          error: (_, _) => const AppPreferences(),
          loading: () => const AppPreferences(),
        );
    final themeMode = switch (preferences.themeMode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
    final contrastLevel = preferences.highContrastEnabled ? 1.0 : 0.0;
    return MaterialApp(
      title: 'Kapış',
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('tr')],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.light,
          contrastLevel: contrastLevel,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.dark,
          contrastLevel: contrastLevel,
        ),
        useMaterial3: true,
      ),
      themeMode: themeMode,
      themeAnimationDuration: preferences.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: _AccessibilityTextScaler(
              media.textScaler,
              preferences.accessibilityTextSize.scaleFactor,
            ),
            disableAnimations:
                media.disableAnimations || preferences.reduceMotion,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const ListingDiscoveryScreen(),
    );
  }
}

final class _AccessibilityTextScaler extends TextScaler {
  const _AccessibilityTextScaler(this.platformScaler, this.appScaleFactor);

  final TextScaler platformScaler;
  final double appScaleFactor;

  @override
  double scale(double fontSize) =>
      platformScaler.scale(fontSize) * appScaleFactor;

  @override
  double get textScaleFactor => platformScaler.scale(14) / 14 * appScaleFactor;

  @override
  TextScaler clamp({
    double minScaleFactor = 0,
    double maxScaleFactor = double.infinity,
  }) {
    return _AccessibilityTextScaler(
      platformScaler.clamp(
        minScaleFactor: minScaleFactor / appScaleFactor,
        maxScaleFactor: maxScaleFactor / appScaleFactor,
      ),
      appScaleFactor,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _AccessibilityTextScaler &&
      other.platformScaler == platformScaler &&
      other.appScaleFactor == appScaleFactor;

  @override
  int get hashCode => Object.hash(platformScaler, appScaleFactor);
}
