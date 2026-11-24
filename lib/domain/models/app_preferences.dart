import 'pickup_coordinates.dart';

enum UserRoleMode {
  donor('Bağışçı'),
  receiver('Alıcı');

  const UserRoleMode(this.label);

  final String label;
}

/// Local display preferences only; cached badge state is not authorization.
final class AppPreferences {
  const AppPreferences({
    this.roleMode = UserRoleMode.receiver,
    this.onboardingComplete = false,
    this.cachedPickupCoordinates,
    this.studentBadgeCached = false,
  });

  final UserRoleMode roleMode;
  final bool onboardingComplete;
  final PickupCoordinates? cachedPickupCoordinates;
  final bool studentBadgeCached;

  AppPreferences copyWith({
    UserRoleMode? roleMode,
    bool? onboardingComplete,
    PickupCoordinates? cachedPickupCoordinates,
    bool clearCachedPickupCoordinates = false,
    bool? studentBadgeCached,
  }) {
    return AppPreferences(
      roleMode: roleMode ?? this.roleMode,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      cachedPickupCoordinates: clearCachedPickupCoordinates
          ? null
          : cachedPickupCoordinates ?? this.cachedPickupCoordinates,
      studentBadgeCached: studentBadgeCached ?? this.studentBadgeCached,
    );
  }
}
