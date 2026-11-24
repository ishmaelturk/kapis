import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/listing.dart';
import '../../domain/models/pickup_coordinates.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/listing_repository.dart';
import '../../domain/services/turkish_text_normalizer.dart';
import 'listing_firestore_mapper.dart';

final class FirebaseListingRepository implements ListingRepository {
  FirebaseListingRepository(
    this._firestore,
    this._auth, [
    this._mapper = const ListingFirestoreMapper(),
  ]) : _listings = _firestore.collection('listings');

  static const _maximumPageSize = 100;
  static final _documentIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final ListingFirestoreMapper _mapper;
  final CollectionReference<Map<String, dynamic>> _listings;

  @override
  Future<Listing> create(
    ListingDraft draft, {
    required PickupCoordinates pickupCoordinates,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthenticationRequiredException();
    }

    final listingReference = _listings.doc();
    final listing = Listing(
      id: listingReference.id,
      donorId: user.uid,
      title: draft.title,
      description: draft.description,
      pickupArea: draft.pickupArea,
      category: draft.category,
      condition: draft.condition,
      tags: draft.tags,
      approximateMapCoordinates: pickupCoordinates.approximateMapCoordinates,
      createdAt: DateTime.now().toUtc(),
    );
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

    return await findById(listing.id) ??
        (throw StateError('The created listing could not be reloaded.'));
  }

  @override
  Future<Listing> update(
    String listingId,
    ListingDraft draft, {
    required PickupCoordinates pickupCoordinates,
  }) async {
    _validateDocumentId(listingId);
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthenticationRequiredException();
    }

    final listingReference = _listings.doc(listingId);
    final pickupReference = listingReference
        .collection('private')
        .doc('pickup');
    final approximate = pickupCoordinates.approximateMapCoordinates;
    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(listingReference);
      final listing = snapshot.data();
      if (!snapshot.exists || listing == null) {
        throw StateError('The listing no longer exists.');
      }
      if (listing['donorId'] != user.uid ||
          listing['status'] != ListingStatus.available.name) {
        throw StateError('Only your available listings can be edited.');
      }

      transaction.update(listingReference, {
        'title': draft.title,
        'description': draft.description,
        'pickupArea': draft.pickupArea,
        'pickupAreaKey': normalizeTurkishText(draft.pickupArea),
        'category': draft.category.name,
        'condition': draft.condition.name,
        'tags': draft.tags,
        'approximateLatitude': approximate.latitude,
        'approximateLongitude': approximate.longitude,
      });
      transaction.set(pickupReference, {
        'latitude': pickupCoordinates.latitude,
        'longitude': pickupCoordinates.longitude,
      });
    });

    return await findById(listingId) ??
        (throw StateError('The updated listing could not be reloaded.'));
  }

  @override
  Future<void> withdraw(String listingId) async {
    _validateDocumentId(listingId);
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthenticationRequiredException();
    }
    final reference = _listings.doc(listingId);
    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(reference);
      final listing = snapshot.data();
      if (!snapshot.exists || listing == null) {
        throw StateError('The listing no longer exists.');
      }
      if (listing['donorId'] != user.uid ||
          listing['status'] != ListingStatus.available.name) {
        throw StateError('Only your available listings can be withdrawn.');
      }
      transaction.update(reference, {'status': ListingStatus.withdrawn.name});
    });
  }

  @override
  Future<void> updateImagePaths(
    String listingId,
    List<String> imagePaths,
  ) async {
    _validateDocumentId(listingId);
    if (imagePaths.length > 1 ||
        imagePaths.any(
          (path) => !RegExp(
            '^listing-images/${RegExp.escape(listingId)}/[A-Za-z0-9_-]{1,128}\$',
          ).hasMatch(path),
        )) {
      throw ArgumentError.value(imagePaths, 'imagePaths');
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthenticationRequiredException();
    }

    final reference = _listings.doc(listingId);
    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(reference);
      final listing = snapshot.data();
      if (!snapshot.exists ||
          listing == null ||
          listing['donorId'] != user.uid ||
          listing['status'] != ListingStatus.available.name) {
        throw StateError('Only your available listings can change photos.');
      }
      transaction.update(reference, {'imagePaths': imagePaths});
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
      query = query.where(
        'pickupAreaKey',
        isEqualTo: normalizeTurkishText(pickupArea),
      );
    }
    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => _mapper.fromDocuments(
            snapshot.docs.map(
              (document) => (id: document.id, data: document.data()),
            ),
          ),
        );
  }

  @override
  Future<List<Listing>> fetchAvailablePage({
    String? pickupArea,
    String? startAfterId,
    int limit = 30,
  }) async {
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
      query = query.where(
        'pickupAreaKey',
        isEqualTo: normalizeTurkishText(pickupArea),
      );
    }
    query = query.orderBy('createdAt', descending: true);
    if (startAfterId != null) {
      _validateDocumentId(startAfterId);
      final cursor = await _listings.doc(startAfterId).get();
      if (!cursor.exists) {
        throw StateError('The listing page cursor no longer exists.');
      }
      query = query.startAfterDocument(cursor);
    }
    final snapshot = await query.limit(limit).get();
    return _mapper.fromDocuments(
      snapshot.docs.map((document) => (id: document.id, data: document.data())),
    );
  }

  @override
  Stream<List<Listing>> watchMyListings({int limit = 100}) {
    if (limit < 1 || limit > _maximumPageSize) {
      throw RangeError.range(limit, 1, _maximumPageSize, 'limit');
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthenticationRequiredException();
    }
    return _listings
        .where('donorId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => _mapper.fromDocuments(
            snapshot.docs.map(
              (document) => (id: document.id, data: document.data()),
            ),
          ),
        );
  }

  @override
  Future<List<Listing>> getAllMyListings() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthenticationRequiredException();
    }

    final baseQuery = _listings
        .where('donorId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true);
    Query<Map<String, dynamic>> query = baseQuery;
    final listings = <Listing>[];
    while (true) {
      final page = await query.limit(_maximumPageSize).get();
      listings.addAll(
        _mapper.fromDocuments(
          page.docs.map((document) => (id: document.id, data: document.data())),
        ),
      );
      if (page.docs.length < _maximumPageSize) {
        return List.unmodifiable(listings);
      }
      query = baseQuery.startAfterDocument(page.docs.last);
    }
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
