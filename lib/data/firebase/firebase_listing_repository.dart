import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/listing.dart';
import '../../domain/models/pickup_coordinates.dart';
import '../../domain/repositories/listing_repository.dart';
import 'listing_firestore_mapper.dart';

final class FirebaseListingRepository implements ListingRepository {
  FirebaseListingRepository(
    this._firestore, [
    this._mapper = const ListingFirestoreMapper(),
  ]) : _listings = _firestore.collection('listings');

  static const _maximumPageSize = 100;
  static final _documentIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

  final FirebaseFirestore _firestore;
  final ListingFirestoreMapper _mapper;
  final CollectionReference<Map<String, dynamic>> _listings;

  @override
  Future<void> create(
    Listing listing, {
    required PickupCoordinates pickupCoordinates,
  }) async {
    _validateDocumentId(listing.id);
    final listingReference = _listings.doc(listing.id);
    final pickupReference = listingReference
        .collection('private')
        .doc('pickup');

    await _firestore.runTransaction<void>((transaction) async {
      final existing = await transaction.get(listingReference);
      if (existing.exists) {
        throw StateError('A listing with this id already exists.');
      }
      transaction.set(listingReference, {
        ..._mapper.toDocument(listing),
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(pickupReference, {
        'latitude': pickupCoordinates.latitude,
        'longitude': pickupCoordinates.longitude,
      });
    });
  }

  @override
  Stream<List<Listing>> watchAvailable({String? pickupArea, int limit = 30}) {
    if (limit < 1 || limit > _maximumPageSize) {
      throw RangeError.range(limit, 1, _maximumPageSize, 'limit');
    }
    if (pickupArea != null && pickupArea.trim().isEmpty) {
      throw ArgumentError.value(
        pickupArea,
        'pickupArea',
        'Must not be blank when provided.',
      );
    }

    Query<Map<String, dynamic>> query = _listings.where(
      'status',
      isEqualTo: ListingStatus.available.name,
    );
    if (pickupArea != null) {
      query = query.where('pickupArea', isEqualTo: pickupArea.trim());
    }
    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => List.unmodifiable(
            snapshot.docs.map(
              (document) => _mapper.fromDocument(document.id, document.data()),
            ),
          ),
        );
  }

  @override
  Future<Listing?> findById(String id) async {
    _validateDocumentId(id);
    final snapshot = await _listings.doc(id).get();
    final document = snapshot.data();
    if (!snapshot.exists || document == null) {
      return null;
    }
    return _mapper.fromDocument(snapshot.id, document);
  }

  @override
  Future<PickupCoordinates> getPickupCoordinatesForHandover(
    String listingId,
  ) async {
    _validateDocumentId(listingId);
    final snapshot = await _listings
        .doc(listingId)
        .collection('private')
        .doc('pickup')
        .get();
    final document = snapshot.data();
    if (!snapshot.exists || document == null) {
      throw StateError(
        'Private pickup coordinates are missing for this listing.',
      );
    }

    final latitude = document['latitude'];
    final longitude = document['longitude'];
    if (latitude is! num || longitude is! num) {
      throw const FormatException('Stored pickup coordinates are invalid.');
    }
    try {
      return PickupCoordinates(
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
      );
    } on ArgumentError {
      throw const FormatException(
        'Stored pickup coordinates are outside valid ranges.',
      );
    }
  }

  void _validateDocumentId(String id) {
    if (!_documentIdPattern.hasMatch(id)) {
      throw ArgumentError.value(
        id,
        'id',
        'Must be a 1-128 character Firestore document id.',
      );
    }
  }
}
