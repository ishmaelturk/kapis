abstract interface class SessionStorage {
  Future<String?> readUserRole();

  Future<void> writeUserRole(String role);

  Future<void> clearUserRole();

  Future<bool?> readCachedStudentBadgeVerified();

  Future<void> writeCachedStudentBadgeVerified(bool verified);

  Future<CachedCoordinates?> readCachedCoordinates();

  Future<void> writeCachedCoordinates(CachedCoordinates coordinates);

  Future<void> clearCachedCoordinates();
}

final class CachedCoordinates {
  const CachedCoordinates({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}
