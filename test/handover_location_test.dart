import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kapis/domain/models/handover_qr_payload.dart';
import 'package:kapis/domain/models/pickup_coordinates.dart';
import 'package:kapis/domain/services/pickup_proximity_service.dart';

void main() {
  test(
    'public map coordinates are rounded away from the exact pickup point',
    () {
      final exact = PickupCoordinates(latitude: 41.1234, longitude: 29.9876);

      expect(exact.approximateMapCoordinates.latitude, 41.12);
      expect(exact.approximateMapCoordinates.longitude, 29.99);
    },
  );

  test(
    'conservatively requires measured distance plus accuracy within 100m',
    () {
      expect(
        const PickupGeofenceResult(
          distanceMeters: 70,
          accuracyMeters: 30,
        ).isWithinPickupRadius,
        isTrue,
      );
      expect(
        const PickupGeofenceResult(
          distanceMeters: 70,
          accuracyMeters: 31,
        ).isWithinPickupRadius,
        isFalse,
      );
      expect(
        const PickupGeofenceResult(
          distanceMeters: 1,
          accuracyMeters: 101,
        ).isWithinPickupRadius,
        isFalse,
      );
    },
  );

  test('parses only valid, structured handover QR payloads', () {
    final token = base64Url
        .encode(List<int>.generate(32, (index) => index))
        .replaceAll('=', '');
    final payload = HandoverQrPayload(listingId: 'listing_1', token: token);

    expect(HandoverQrPayload.parse(payload.toString()).listingId, 'listing_1');
    expect(
      () => HandoverQrPayload.parse('${payload.toString()}?unexpected=1'),
      throwsFormatException,
    );
    expect(
      () => HandoverQrPayload(listingId: '../listing', token: token),
      throwsArgumentError,
    );
  });
}
