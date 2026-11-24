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
  static const _schemaVersion = 1;

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
    if (decoded['schemaVersion'] != _schemaVersion) {
      throw FormatException(
        'Unsupported app preferences schema: ${decoded['schemaVersion']}.',
      );
    }

    final roleName = decoded['roleMode'];
    if (roleName is! String) {
      throw const FormatException('Stored role mode is missing or invalid.');
    }
    final roleMode = _roleModeFromName(roleName);
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
        'onboardingComplete': preferences.onboardingComplete,
        'cachedPickupCoordinates': _coordinatesToJson(
          preferences.cachedPickupCoordinates,
        ),
        'studentBadgeCached': preferences.studentBadgeCached,
      }),
    );
  }

  UserRoleMode _roleModeFromName(String name) {
    for (final roleMode in UserRoleMode.values) {
      if (roleMode.name == name) {
        return roleMode;
      }
    }
    throw FormatException('Unknown stored role mode: $name.');
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
