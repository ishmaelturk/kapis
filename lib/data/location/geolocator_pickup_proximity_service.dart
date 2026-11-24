import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/models/pickup_coordinates.dart';
import '../../domain/services/pickup_proximity_service.dart';

final class GeolocatorPickupProximityService implements PickupProximityService {
  const GeolocatorPickupProximityService();

  @override
  Future<PickupGeofenceResult> verifyAtPickup(PickupCoordinates target) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const PickupLocationAccessException(
        'Enable location services to verify pickup proximity.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const PickupLocationAccessException(
        'Location permission is disabled. Enable it in system settings.',
      );
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      throw const PickupLocationAccessException(
        'Location permission is required to verify pickup proximity.',
      );
    }

    final settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 20),
            forceLocationManager: true,
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          );
    final position = await Geolocator.getCurrentPosition(
      locationSettings: settings,
    );
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
}
