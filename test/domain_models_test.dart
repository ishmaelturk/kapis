import 'package:flutter_test/flutter_test.dart';
import 'package:kapis/domain/models/listing.dart';
import 'package:kapis/domain/models/pickup_coordinates.dart';

void main() {
  group('PickupCoordinates', () {
    test('rejects invalid geographic ranges and non-finite values', () {
      expect(
        () => PickupCoordinates(latitude: 91, longitude: 0),
        throwsArgumentError,
      );
      expect(
        () => PickupCoordinates(latitude: 0, longitude: double.infinity),
        throwsArgumentError,
      );
    });
  });

  group('Listing', () {
    test('keeps tags immutable and defaults to pickup available', () {
      final tags = ['desk'];
      final listing = Listing(
        id: 'listing-1',
        donorId: 'donor-1',
        title: 'Desk',
        description: 'A sturdy desk.',
        category: ListingCategory.tablesAndDesks,
        condition: ItemCondition.good,
        tags: tags,
        pickupCoordinates: PickupCoordinates(latitude: 41, longitude: 29),
        createdAt: DateTime.utc(2026),
      );
      tags.add('extra');

      expect(listing.tags, ['desk']);
      expect(listing.isAvailable, isTrue);
      expect(() => listing.tags.add('extra'), throwsUnsupportedError);
    });

    test('rejects blank required text', () {
      expect(
        () => Listing(
          id: 'listing-1',
          donorId: 'donor-1',
          title: ' ',
          description: 'A sturdy desk.',
          category: ListingCategory.tablesAndDesks,
          condition: ItemCondition.good,
          tags: const [],
          pickupCoordinates: PickupCoordinates(latitude: 41, longitude: 29),
          createdAt: DateTime.utc(2026),
        ),
        throwsArgumentError,
      );
    });
  });
}
