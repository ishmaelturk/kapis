import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/app_preferences.dart';
import '../../domain/models/pickup_coordinates.dart';
import '../../domain/repositories/app_preferences_repository.dart';

final class SharedPreferencesAppPreferencesRepository
    implements AppPreferencesRepository {
  SharedPreferencesAppPreferencesRepository({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  static const _storageKey = 'kapis.app_preferences';
  static const _schemaVersion = 3;

  final SharedPreferencesAsync _preferences;

  @override
  Future<AppPreferences> load() async {
    final storedValue = await _preferences.getString(_storageKey);
    if (storedValue == null) {
      return const AppPreferences();
    }

    final decoded = jsonDecode(storedValue);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Stored app preferences must be an object.');
    }
    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion != 1 &&
        schemaVersion != 2 &&
        schemaVersion != _schemaVersion) {
      throw FormatException(
        'Unsupported app preferences schema: $schemaVersion.',
      );
    }

    final roleName = decoded['roleMode'];
    if (roleName is! String) {
      throw const FormatException('Stored role mode is missing or invalid.');
    }
    final roleMode = _roleModeFromName(roleName);
    final storedThemeMode = decoded['themeMode'];
    final themeMode = schemaVersion == 1 && storedThemeMode == null
        ? AppThemeMode.system
        : _themeModeFromName(storedThemeMode);
    final storedTextSize = decoded['accessibilityTextSize'];
    final accessibilityTextSize = schemaVersion < 3 && storedTextSize == null
        ? AccessibilityTextSize.normal
        : _accessibilityTextSizeFromName(storedTextSize);
    final highContrastEnabled = _readAccessibilityBool(
      decoded['highContrastEnabled'],
      schemaVersion,
      'high contrast',
    );
    final reduceMotion = _readAccessibilityBool(
      decoded['reduceMotion'],
      schemaVersion,
      'reduce motion',
    );
    final onboardingComplete = decoded['onboardingComplete'];
    if (onboardingComplete is! bool) {
      throw const FormatException(
        'Stored onboarding state is missing or invalid.',
      );
    }
    final studentBadgeCached = decoded['studentBadgeCached'];
    if (studentBadgeCached is! bool) {
      throw const FormatException('Stored student badge state is invalid.');
    }

    return AppPreferences(
      roleMode: roleMode,
      themeMode: themeMode,
      accessibilityTextSize: accessibilityTextSize,
      highContrastEnabled: highContrastEnabled,
      reduceMotion: reduceMotion,
      onboardingComplete: onboardingComplete,
      cachedPickupCoordinates: _readCoordinates(
        decoded['cachedPickupCoordinates'],
      ),
      studentBadgeCached: studentBadgeCached,
    );
  }

  @override
  Future<void> save(AppPreferences preferences) {
    return _preferences.setString(
      _storageKey,
      jsonEncode({
        'schemaVersion': _schemaVersion,
        'roleMode': preferences.roleMode.name,
        'themeMode': preferences.themeMode.name,
        'accessibilityTextSize': preferences.accessibilityTextSize.name,
        'highContrastEnabled': preferences.highContrastEnabled,
        'reduceMotion': preferences.reduceMotion,
        'onboardingComplete': preferences.onboardingComplete,
        'cachedPickupCoordinates': _coordinatesToJson(
          preferences.cachedPickupCoordinates,
        ),
        'studentBadgeCached': preferences.studentBadgeCached,
      }),
    );
  }

  @override
  Future<void> reset() => _preferences.remove(_storageKey);

  UserRoleMode _roleModeFromName(String name) {
    for (final roleMode in UserRoleMode.values) {
      if (roleMode.name == name) {
        return roleMode;
      }
    }
    throw FormatException('Unknown stored role mode: $name.');
  }

  AppThemeMode _themeModeFromName(Object? storedValue) {
    if (storedValue is! String) {
      throw const FormatException('Stored theme mode is missing or invalid.');
    }
    for (final themeMode in AppThemeMode.values) {
      if (themeMode.name == storedValue) {
        return themeMode;
      }
    }
    throw FormatException('Unknown stored theme mode: $storedValue.');
  }

  AccessibilityTextSize _accessibilityTextSizeFromName(Object? storedValue) {
    if (storedValue is! String) {
      throw const FormatException(
        'Stored accessibility text size is missing or invalid.',
      );
    }
    for (final textSize in AccessibilityTextSize.values) {
      if (textSize.name == storedValue) {
        return textSize;
      }
    }
    throw FormatException('Unknown accessibility text size: $storedValue.');
  }

  bool _readAccessibilityBool(Object? value, int schemaVersion, String name) {
    if (schemaVersion < 3 && value == null) {
      return false;
    }
    if (value is! bool) {
      throw FormatException('Stored $name preference is missing or invalid.');
    }
    return value;
  }

  Map<String, double>? _coordinatesToJson(PickupCoordinates? coordinates) {
    if (coordinates == null) {
      return null;
    }
    return {
      'latitude': coordinates.latitude,
      'longitude': coordinates.longitude,
    };
  }

  PickupCoordinates? _readCoordinates(Object? storedValue) {
    if (storedValue == null) {
      return null;
    }
    if (storedValue is! Map<String, dynamic>) {
      throw const FormatException('Stored pickup coordinates are invalid.');
    }

    final latitude = storedValue['latitude'];
    final longitude = storedValue['longitude'];
    if (latitude is! num || longitude is! num) {
      throw const FormatException('Stored pickup coordinates are invalid.');
    }

    try {
      return PickupCoordinates(
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
      );
    } on ArgumentError {
      throw const FormatException(
        'Stored pickup coordinates are outside valid ranges.',
      );
    }
  }
}
