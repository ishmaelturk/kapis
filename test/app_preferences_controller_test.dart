import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapis/application/app_preferences_controller.dart';
import 'package:kapis/domain/models/app_preferences.dart';
import 'package:kapis/domain/models/pickup_coordinates.dart';
import 'package:kapis/domain/repositories/app_preferences_repository.dart';

void main() {
  test('persists preference changes before publishing updated state', () async {
    final repository = _MemoryAppPreferencesRepository();
    final container = ProviderContainer(
      overrides: [
        appPreferencesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(appPreferencesProvider.future);
    final controller = container.read(appPreferencesProvider.notifier);
    await controller.setRoleMode(UserRoleMode.donor);
    await controller.cachePickupCoordinates(
      PickupCoordinates(latitude: 41, longitude: 29),
    );

    final preferences = container.read(appPreferencesProvider).requireValue;
    expect(preferences.roleMode, UserRoleMode.donor);
    expect(preferences.cachedPickupCoordinates?.latitude, 41);
    expect(repository.value.roleMode, UserRoleMode.donor);
    expect(repository.saveCount, 2);
  });

  test('persists the selected theme mode before publishing it', () async {
    final repository = _MemoryAppPreferencesRepository();
    final container = ProviderContainer(
      overrides: [
        appPreferencesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(appPreferencesProvider.future);
    await container
        .read(appPreferencesProvider.notifier)
        .setThemeMode(AppThemeMode.dark);

    expect(
      container.read(appPreferencesProvider).requireValue.themeMode,
      AppThemeMode.dark,
    );
    expect(repository.value.themeMode, AppThemeMode.dark);
    expect(repository.saveCount, 1);
  });

  test('persists accessibility preferences together', () async {
    final repository = _MemoryAppPreferencesRepository();
    final container = ProviderContainer(
      overrides: [
        appPreferencesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(appPreferencesProvider.future);
    final controller = container.read(appPreferencesProvider.notifier);
    await controller.setAccessibilityTextSize(AccessibilityTextSize.extraLarge);
    await controller.setHighContrastEnabled(true);
    await controller.setReduceMotion(true);

    final preferences = container.read(appPreferencesProvider).requireValue;
    expect(preferences.accessibilityTextSize, AccessibilityTextSize.extraLarge);
    expect(preferences.highContrastEnabled, isTrue);
    expect(preferences.reduceMotion, isTrue);
    expect(
      repository.value.accessibilityTextSize,
      AccessibilityTextSize.extraLarge,
    );
    expect(repository.value.highContrastEnabled, isTrue);
    expect(repository.value.reduceMotion, isTrue);
    expect(repository.saveCount, 3);
  });

  test('surfaces storage failures and keeps the previous state', () async {
    final repository = _MemoryAppPreferencesRepository()..failWrites = true;
    final container = ProviderContainer(
      overrides: [
        appPreferencesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(appPreferencesProvider.future);
    final controller = container.read(appPreferencesProvider.notifier);

    await expectLater(
      controller.setRoleMode(UserRoleMode.donor),
      throwsStateError,
    );
    expect(
      container.read(appPreferencesProvider).requireValue.roleMode,
      UserRoleMode.receiver,
    );
  });

  test('serializes overlapping changes without losing either update', () async {
    final repository = _MemoryAppPreferencesRepository()
      ..writeGate = Completer<void>();
    final container = ProviderContainer(
      overrides: [
        appPreferencesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(appPreferencesProvider.future);
    final controller = container.read(appPreferencesProvider.notifier);
    final roleChange = controller.setRoleMode(UserRoleMode.donor);
    final onboardingChange = controller.setOnboardingComplete(true);

    await Future<void>.delayed(Duration.zero);
    expect(repository.saveAttempts, 1);
    repository.writeGate!.complete();
    await Future.wait([roleChange, onboardingChange]);

    final preferences = container.read(appPreferencesProvider).requireValue;
    expect(preferences.roleMode, UserRoleMode.donor);
    expect(preferences.onboardingComplete, isTrue);
    expect(repository.saveCount, 2);
  });

  test('resets malformed stored preferences and returns defaults', () async {
    final repository = _MemoryAppPreferencesRepository()
      ..loadError = const FormatException('Unknown theme.');
    final container = ProviderContainer(
      overrides: [
        appPreferencesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final preferences = await container.read(appPreferencesProvider.future);

    expect(preferences, const AppPreferences());
    expect(repository.resetCount, 1);
  });

  test(
    'waits for preferences to load before applying an early setter',
    () async {
      final repository = _MemoryAppPreferencesRepository()
        ..loadGate = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          appPreferencesRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final load = container.read(appPreferencesProvider.future);
      final update = container
          .read(appPreferencesProvider.notifier)
          .setThemeMode(AppThemeMode.dark);
      await Future<void>.delayed(Duration.zero);
      expect(repository.saveAttempts, 0);

      repository.loadGate!.complete();
      await Future.wait([load, update]);

      expect(
        container.read(appPreferencesProvider).requireValue.themeMode,
        AppThemeMode.dark,
      );
      expect(repository.saveCount, 1);
    },
  );
}

final class _MemoryAppPreferencesRepository
    implements AppPreferencesRepository {
  AppPreferences value = const AppPreferences();
  bool failWrites = false;
  Completer<void>? writeGate;
  Completer<void>? loadGate;
  FormatException? loadError;
  int saveAttempts = 0;
  int saveCount = 0;
  int resetCount = 0;

  @override
  Future<AppPreferences> load() async {
    await loadGate?.future;
    if (loadError case final error?) {
      throw error;
    }
    return value;
  }

  @override
  Future<void> save(AppPreferences preferences) async {
    saveAttempts++;
    if (failWrites) {
      throw StateError('Storage unavailable.');
    }
    await writeGate?.future;
    value = preferences;
    saveCount++;
  }

  @override
  Future<void> reset() async {
    resetCount++;
    loadError = null;
    value = const AppPreferences();
  }
}
