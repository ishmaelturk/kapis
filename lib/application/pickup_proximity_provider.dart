import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/location/geolocator_pickup_proximity_service.dart';
import '../domain/services/pickup_proximity_service.dart';

final pickupProximityServiceProvider = Provider<PickupProximityService>(
  (ref) => const GeolocatorPickupProximityService(),
);
