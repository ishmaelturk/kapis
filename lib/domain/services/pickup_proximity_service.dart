import '../models/pickup_coordinates.dart';

final class PickupGeofenceResult {
  const PickupGeofenceResult({
    required this.distanceMeters,
    required this.accuracyMeters,
  });

  static const radiusMeters = 100.0;

  final double distanceMeters;
  final double accuracyMeters;

  bool get isWithinPickupRadius {
    if (!distanceMeters.isFinite ||
        !accuracyMeters.isFinite ||
        distanceMeters < 0 ||
        accuracyMeters < 0) {
      return false;
    }
    return distanceMeters + accuracyMeters <= radiusMeters;
  }
}

abstract interface class PickupProximityService {
  Future<PickupCoordinates?> getCurrentCoordinates({
    bool requestPermission = true,
  });

  Future<PickupGeofenceResult> verifyAtPickup(PickupCoordinates target);
}

final class PickupLocationAccessException implements Exception {
  const PickupLocationAccessException(this.message);

  final String message;

  @override
  String toString() => message;
}
