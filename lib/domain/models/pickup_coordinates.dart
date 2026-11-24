final class PickupCoordinates {
  const PickupCoordinates._(this.latitude, this.longitude);

  factory PickupCoordinates({
    required double latitude,
    required double longitude,
  }) {
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw ArgumentError.value(latitude, 'latitude', 'Must be between -90 and 90.');
    }
    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      throw ArgumentError.value(
        longitude,
        'longitude',
        'Must be between -180 and 180.',
      );
    }
    return PickupCoordinates._(latitude, longitude);
  }

  final double latitude;
  final double longitude;
}
