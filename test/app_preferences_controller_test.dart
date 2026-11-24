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
}

final class _MemoryAppPreferencesRepository
    implements AppPreferencesRepository {
  AppPreferences value = const AppPreferences();
  bool failWrites = false;
  Completer<void>? writeGate;
  int saveAttempts = 0;
  int saveCount = 0;

  @override
  Future<AppPreferences> load() async => value;

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
}
