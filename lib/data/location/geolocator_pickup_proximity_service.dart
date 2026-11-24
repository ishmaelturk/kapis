import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/models/pickup_coordinates.dart';
import '../../domain/services/pickup_proximity_service.dart';

final class GeolocatorPickupProximityService implements PickupProximityService {
  const GeolocatorPickupProximityService();

  @override
  Future<PickupCoordinates?> getCurrentCoordinates({
    bool requestPermission = true,
  }) async {
    final position = await _getCurrentPosition(
      requestPermission: requestPermission,
    );
    if (position == null) {
      return null;
    }
    return PickupCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  @override
  Future<PickupGeofenceResult> verifyAtPickup(PickupCoordinates target) async {
    final position = await _getCurrentPosition(requestPermission: true);
    if (position == null) {
      throw const PickupLocationAccessException(
        'Location permission is required to verify pickup proximity.',
      );
    }
    final distanceMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      target.latitude,
      target.longitude,
    );

    return PickupGeofenceResult(
      distanceMeters: distanceMeters,
      accuracyMeters: position.accuracy,
    );
  }

  Future<Position?> _getCurrentPosition({
    required bool requestPermission,
  }) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!requestPermission) {
        return null;
      }
      throw const PickupLocationAccessException(
        'Enable location services to verify pickup proximity.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (!requestPermission) {
        return null;
      }
      throw const PickupLocationAccessException(
        'Location permission is disabled. Enable it in system settings.',
      );
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      if (!requestPermission) {
        return null;
      }
      throw const PickupLocationAccessException(
        'Location permission is required to verify pickup proximity.',
      );
    }

    final settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 20),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          );
    return Geolocator.getCurrentPosition(locationSettings: settings);
  }
}
