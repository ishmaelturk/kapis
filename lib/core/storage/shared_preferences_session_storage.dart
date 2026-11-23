import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'session_storage.dart';

final sessionStorageProvider = FutureProvider<SessionStorage>((ref) async {
  final preferences = await SharedPreferences.getInstance();
  return SharedPreferencesSessionStorage(preferences);
});

class SharedPreferencesSessionStorage implements SessionStorage {
  SharedPreferencesSessionStorage(this._preferences);

  static const _userRoleKey = 'user_role';
  static const _studentBadgeVerifiedKey = 'student_badge_verified';
  static const _cachedCoordinatesKey = 'cached_coordinates';

  final SharedPreferences _preferences;

  @override
  Future<String?> readUserRole() async {
    return _preferences.getString(_userRoleKey);
  }

  @override
  Future<void> writeUserRole(String role) async {
    await _save(
      _preferences.setString(_userRoleKey, role),
      'save the user role',
    );
  }

  @override
  Future<void> clearUserRole() async {
    await _save(_preferences.remove(_userRoleKey), 'clear the user role');
  }

  @override
  Future<bool?> readCachedStudentBadgeVerified() async {
    return _preferences.getBool(_studentBadgeVerifiedKey);
  }

  @override
  Future<void> writeCachedStudentBadgeVerified(bool verified) async {
    await _save(
      _preferences.setBool(_studentBadgeVerifiedKey, verified),
      'save the student badge cache',
    );
  }

  @override
  Future<CachedCoordinates?> readCachedCoordinates() async {
    final value = _preferences.getString(_cachedCoordinatesKey);
    if (value == null) {
      return null;
    }

    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Cached coordinates are not a JSON object.');
    }

    final latitude = decoded['latitude'];
    final longitude = decoded['longitude'];
    if (latitude is! num || longitude is! num) {
      throw const FormatException('Cached coordinates are incomplete.');
    }

    return CachedCoordinates(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
    );
  }

  @override
  Future<void> writeCachedCoordinates(CachedCoordinates coordinates) async {
    final value = jsonEncode({
      'latitude': coordinates.latitude,
      'longitude': coordinates.longitude,
    });
    await _save(
      _preferences.setString(_cachedCoordinatesKey, value),
      'save cached coordinates',
    );
  }

  @override
  Future<void> clearCachedCoordinates() async {
    await _save(
      _preferences.remove(_cachedCoordinatesKey),
      'clear cached coordinates',
    );
  }

  Future<void> _save(Future<bool> operation, String description) async {
    if (!await operation) {
      throw StateError('Could not $description in shared preferences.');
    }
  }
}
