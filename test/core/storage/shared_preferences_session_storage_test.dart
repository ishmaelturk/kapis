import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kapis/core/storage/session_storage.dart';
import 'package:kapis/core/storage/shared_preferences_session_storage.dart';

void main() {
  late SharedPreferences preferences;
  late SharedPreferencesSessionStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    storage = SharedPreferencesSessionStorage(preferences);
  });

  test('stores lightweight session metadata and cached coordinates', () async {
    expect(await storage.readUserRole(), isNull);
    expect(await storage.readCachedStudentBadgeVerified(), isNull);
    expect(await storage.readCachedCoordinates(), isNull);

    await storage.writeUserRole('donor');
    await storage.writeCachedStudentBadgeVerified(true);
    await storage.writeCachedCoordinates(
      const CachedCoordinates(latitude: 41.01, longitude: 28.97),
    );

    expect(await storage.readUserRole(), 'donor');
    expect(await storage.readCachedStudentBadgeVerified(), isTrue);
    final coordinates = await storage.readCachedCoordinates();
    expect(coordinates?.latitude, 41.01);
    expect(coordinates?.longitude, 28.97);

    await storage.clearUserRole();
    await storage.clearCachedCoordinates();

    expect(await storage.readUserRole(), isNull);
    expect(await storage.readCachedCoordinates(), isNull);
  });

  test('allows replacing the storage provider in tests', () async {
    final container = ProviderContainer(
      overrides: [
        sessionStorageProvider.overrideWith((ref) async => storage),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(sessionStorageProvider.future), same(storage));
  });

  test(
    'reports malformed cached coordinates instead of hiding corruption',
    () async {
      await preferences.setString('cached_coordinates', '{"latitude":41}');

      expect(
        storage.readCachedCoordinates(),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
