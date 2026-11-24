import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapis/data/firebase/listing_firestore_mapper.dart';
import 'package:kapis/domain/models/listing.dart';
import 'package:kapis/domain/models/pickup_coordinates.dart';

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
    approximateMapCoordinates: PickupCoordinates(
      latitude: 41.0,
      longitude: 29.0,
    ),
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
      expect(document['pickupAreaKey'], 'kadikoy');
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

  test('rejects an inconsistent normalized pickup area key', () {
    expect(
      () => mapper.fromDocument(listing.id, {
        ...mapper.toDocument(listing),
        'pickupAreaKey': 'istanbul',
      }),
      throwsFormatException,
    );
  });

  test('round-trips an optional listing image path', () {
    final withImage = Listing(
      id: listing.id,
      donorId: listing.donorId,
      title: listing.title,
      description: listing.description,
      pickupArea: listing.pickupArea,
      category: listing.category,
      condition: listing.condition,
      tags: listing.tags,
      approximateMapCoordinates: listing.approximateMapCoordinates,
      createdAt: listing.createdAt,
      imagePaths: const ['listing-images/listing-1/primary'],
    );
    final document = mapper.toDocument(withImage);
    final restored = mapper.fromDocument(withImage.id, {
      ...document,
      'createdAt': Timestamp.fromDate(withImage.createdAt),
    });

    expect(restored.imagePaths, withImage.imagePaths);
  });

  test('rejects listing image paths outside its storage directory', () {
    expect(
      () => mapper.fromDocument(listing.id, {
        ...mapper.toDocument(listing),
        'imagePaths': ['listing-images/another-listing/primary'],
        'createdAt': Timestamp.fromDate(listing.createdAt),
      }),
      throwsArgumentError,
    );
  });

  test('skips malformed documents without dropping valid listings', () {
    final document = {
      ...mapper.toDocument(listing),
      'createdAt': Timestamp.fromDate(listing.createdAt),
    };

    final result = mapper.fromDocuments([
      (id: 'blank-title', data: {...document, 'title': '   '}),
      (
        id: 'blank-tag',
        data: {
          ...document,
          'tags': ['   '],
        },
      ),
      (id: listing.id, data: document),
    ]);

    expect(result.map((item) => item.id), [listing.id]);
  });
}
