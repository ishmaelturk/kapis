import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapis/data/firebase/listing_firestore_mapper.dart';
import 'package:kapis/domain/models/listing.dart';

void main() {
  const mapper = ListingFirestoreMapper();
  final listing = Listing(
    id: 'listing-1',
    donorId: 'donor-1',
    title: 'Desk',
    description: 'A sturdy desk.',
    pickupArea: 'Kadıköy',
    category: ListingCategory.tablesAndDesks,
    condition: ItemCondition.good,
    tags: const ['desk'],
    createdAt: DateTime.utc(2026, 11, 24),
  );

  test(
    'round-trips listing data without exposing exact pickup coordinates',
    () {
      final document = mapper.toDocument(listing);
      final restored = mapper.fromDocument(listing.id, {
        ...document,
        'createdAt': Timestamp.fromDate(listing.createdAt),
      });

      expect(document.containsKey('pickupCoordinates'), isFalse);
      expect(restored.id, listing.id);
      expect(restored.pickupArea, listing.pickupArea);
      expect(restored.tags, listing.tags);
    },
  );

  test('rejects exact coordinates in a public listing document', () {
    expect(
      () => mapper.fromDocument(listing.id, {
        ...mapper.toDocument(listing),
        'pickupCoordinates': {'latitude': 41, 'longitude': 29},
      }),
      throwsFormatException,
    );
  });
}
