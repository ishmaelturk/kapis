import 'pickup_coordinates.dart';

enum UserRoleMode {
  donor('Bağışçı'),
  receiver('Alıcı');

  const UserRoleMode(this.label);

  final String label;
}

enum AppThemeMode { system, light, dark }

enum AccessibilityTextSize {
  normal(1.0),
  large(1.2),
  extraLarge(1.4);

  const AccessibilityTextSize(this.scaleFactor);

  final double scaleFactor;
}

/// Local display preferences only; cached badge state is not authorization.
final class AppPreferences {
  const AppPreferences({
    this.roleMode = UserRoleMode.receiver,
    this.themeMode = AppThemeMode.system,
    this.accessibilityTextSize = AccessibilityTextSize.normal,
    this.highContrastEnabled = false,
    this.reduceMotion = false,
    this.onboardingComplete = false,
    this.cachedPickupCoordinates,
    this.studentBadgeCached = false,
  });

  final UserRoleMode roleMode;
  final AppThemeMode themeMode;
  final AccessibilityTextSize accessibilityTextSize;
  final bool highContrastEnabled;
  final bool reduceMotion;
  final bool onboardingComplete;
  final PickupCoordinates? cachedPickupCoordinates;
  final bool studentBadgeCached;

  AppPreferences copyWith({
    UserRoleMode? roleMode,
    AppThemeMode? themeMode,
    AccessibilityTextSize? accessibilityTextSize,
    bool? highContrastEnabled,
    bool? reduceMotion,
    bool? onboardingComplete,
    PickupCoordinates? cachedPickupCoordinates,
    bool clearCachedPickupCoordinates = false,
    bool? studentBadgeCached,
  }) {
    return AppPreferences(
      roleMode: roleMode ?? this.roleMode,
      themeMode: themeMode ?? this.themeMode,
      accessibilityTextSize:
          accessibilityTextSize ?? this.accessibilityTextSize,
      highContrastEnabled: highContrastEnabled ?? this.highContrastEnabled,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      cachedPickupCoordinates: clearCachedPickupCoordinates
          ? null
          : cachedPickupCoordinates ?? this.cachedPickupCoordinates,
      studentBadgeCached: studentBadgeCached ?? this.studentBadgeCached,
    );
  }
}
