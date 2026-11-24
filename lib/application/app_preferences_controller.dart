import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/preferences/shared_preferences_app_preferences_repository.dart';
import '../domain/models/app_preferences.dart';
import '../domain/models/pickup_coordinates.dart';
import '../domain/repositories/app_preferences_repository.dart';

final appPreferencesRepositoryProvider = Provider<AppPreferencesRepository>(
  (ref) => SharedPreferencesAppPreferencesRepository(
    preferences: SharedPreferencesAsync(),
  ),
);

final appPreferencesProvider =
    AsyncNotifierProvider<AppPreferencesController, AppPreferences>(
      AppPreferencesController.new,
    );

final class AppPreferencesController extends AsyncNotifier<AppPreferences> {
  Future<void> _writeQueue = Future<void>.value();

  @override
  Future<AppPreferences> build() async {
    final repository = ref.watch(appPreferencesRepositoryProvider);
    try {
      return await repository.load();
    } on FormatException catch (error, stackTrace) {
      log(
        'Resetting malformed app preferences.',
        name: 'AppPreferencesController',
        error: error,
        stackTrace: stackTrace,
      );
      await repository.reset();
      return const AppPreferences();
    }
  }

  Future<void> setRoleMode(UserRoleMode roleMode) {
    return _update((current) => current.copyWith(roleMode: roleMode));
  }

  Future<void> setThemeMode(AppThemeMode themeMode) {
    return _update((current) => current.copyWith(themeMode: themeMode));
  }

  Future<void> setAccessibilityTextSize(AccessibilityTextSize textSize) {
    return _update(
      (current) => current.copyWith(accessibilityTextSize: textSize),
    );
  }

  Future<void> setHighContrastEnabled(bool enabled) {
    return _update((current) => current.copyWith(highContrastEnabled: enabled));
  }

  Future<void> setReduceMotion(bool enabled) {
    return _update((current) => current.copyWith(reduceMotion: enabled));
  }

  Future<void> setOnboardingComplete(bool complete) {
    return _update((current) => current.copyWith(onboardingComplete: complete));
  }

  Future<void> cachePickupCoordinates(PickupCoordinates coordinates) {
    return _update(
      (current) => current.copyWith(cachedPickupCoordinates: coordinates),
    );
  }

  Future<void> clearCachedPickupCoordinates() {
    return _update(
      (current) => current.copyWith(clearCachedPickupCoordinates: true),
    );
  }

  Future<void> cacheStudentBadge(bool verified) {
    return _update((current) => current.copyWith(studentBadgeCached: verified));
  }

  Future<void> _update(
    AppPreferences Function(AppPreferences current) update,
  ) async {
    final operation = _writeQueue.then((_) async {
      final current = await future;
      final updated = update(current);
      await ref.read(appPreferencesRepositoryProvider).save(updated);
      state = AsyncData(updated);
    });
    _writeQueue = operation.catchError((Object _) {});
    return operation;
  }
}
