import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/handover_qr_payload.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/pickup_coordinates.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/handover_repository.dart';
import 'listing_firestore_mapper.dart';

final class FirebaseHandoverRepository implements HandoverRepository {
  FirebaseHandoverRepository(this._firestore, this._auth);

  static final _listingIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final _listingMapper = const ListingFirestoreMapper();

  CollectionReference<Map<String, dynamic>> get _listings =>
      _firestore.collection('listings');

  @override
  Future<void> reserveListing(String listingId) async {
    _validateListingId(listingId);
    final user = _requireUser();
    final listingReference = _listings.doc(listingId);
    final reservationReference = listingReference
        .collection('private')
        .doc('reservation');

    await _releaseExpiredReservationIfNeeded(
      listingReference,
      reservationReference,
    );

    await _firestore.runTransaction<void>((transaction) async {
      final listingSnapshot = await transaction.get(listingReference);
      final reservationSnapshot = await transaction.get(reservationReference);
      final listing = listingSnapshot.data();
      if (!listingSnapshot.exists || listing == null) {
        throw StateError('The listing no longer exists.');
      }
      if (listing['donorId'] == user.uid) {
        throw StateError('You cannot reserve your own listing.');
      }
      if (listing['status'] != 'available') {
        throw StateError('This listing is no longer available.');
      }
      if (reservationSnapshot.exists) {
        throw StateError('This listing has a stale reservation.');
      }

      final slotReferences = List.generate(
        3,
        (index) => _reservationSlot(user.uid, 'slot-${index + 1}'),
      );
      final slotSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final reference in slotReferences) {
        slotSnapshots.add(await transaction.get(reference));
      }
      final availableSlotIndex = slotSnapshots.indexWhere(
        (snapshot) => !snapshot.exists,
      );
      if (availableSlotIndex == -1) {
        throw StateError('You already have three active reservations.');
      }

      final slotReference = slotReferences[availableSlotIndex];
      transaction.update(listingReference, {'status': 'reserved'});
      transaction.set(reservationReference, {
        'receiverId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().toUtc().add(const Duration(hours: 47)),
        ),
        'slotId': 'slot-${availableSlotIndex + 1}',
      });
      transaction.set(slotReference, {'listingId': listingReference.id});
    });
  }

  @override
  Future<void> cancelReservation(String listingId) async {
    _validateListingId(listingId);
    final user = _requireUser();
    await _changeReservationStatus(
      listingId,
      user.uid,
      status: 'available',
      requireReceiver: true,
    );
  }

  @override
  Future<void> releaseReservation(
    String listingId, {
    bool withdraw = false,
  }) async {
    _validateListingId(listingId);
    final user = _requireUser();
    await _changeReservationStatus(
      listingId,
      user.uid,
      status: withdraw ? 'withdrawn' : 'available',
      requireReceiver: false,
    );
  }

  @override
  Stream<List<Listing>> watchMyReservations() {
    final user = _requireUser();
    final slots = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('private')
        .doc('reservationSlots')
        .collection('slots')
        .limit(3);

    return slots.snapshots().asyncMap((snapshot) async {
      final documents = <({String id, Map<String, dynamic> data})>[];
      for (final slot in snapshot.docs) {
        final listingId = slot.data()['listingId'];
        if (listingId is! String || !_listingIdPattern.hasMatch(listingId)) {
          throw const FormatException(
            'Stored reservation slot has an invalid listing id.',
          );
        }
        final listingSnapshot = await _listings.doc(listingId).get();
        final data = listingSnapshot.data();
        if (listingSnapshot.exists && data != null) {
          documents.add((id: listingSnapshot.id, data: data));
        }
      }

      return _listingMapper
          .fromDocuments(documents)
          .where((listing) => listing.status == ListingStatus.reserved)
          .toList(growable: false);
    });
  }

  @override
  Stream<ListingStatus?> watchListingStatus(String listingId) {
    _validateListingId(listingId);
    return _listings.doc(listingId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      final status = snapshot.data()?['status'];
      for (final value in ListingStatus.values) {
        if (value.name == status) {
          return value;
        }
      }
      throw const FormatException('Listing status is invalid.');
    });
  }

  Future<void> _releaseExpiredReservationIfNeeded(
    DocumentReference<Map<String, dynamic>> listingReference,
    DocumentReference<Map<String, dynamic>> reservationReference,
  ) async {
    await _firestore.runTransaction<void>((transaction) async {
      final listingSnapshot = await transaction.get(listingReference);
      final listing = listingSnapshot.data();
      if (!listingSnapshot.exists || listing == null) {
        throw StateError('The listing no longer exists.');
      }
      if (listing['status'] != 'reserved') {
        return;
      }

      final reservationSnapshot = await transaction.get(reservationReference);
      final reservation = reservationSnapshot.data();
      if (!reservationSnapshot.exists ||
          reservation == null ||
          !_isExpired(reservation)) {
        throw StateError('This listing is already reserved.');
      }
      if (_isConfirmed(reservation)) {
        throw StateError('The handover has already been confirmed.');
      }

      DocumentReference<Map<String, dynamic>>? slotReference;
      final receiverId = reservation['receiverId'];
      final slotId = reservation['slotId'];
      if (receiverId is String && slotId is String) {
        slotReference = _reservationSlot(receiverId, slotId);
      }

      transaction.update(listingReference, {'status': 'available'});
      transaction.delete(reservationReference);
      if (slotReference != null) {
        transaction.delete(slotReference);
      }
    });
  }

  Future<void> _changeReservationStatus(
    String listingId,
    String userId, {
    required String status,
    required bool requireReceiver,
  }) async {
    final listingReference = _listings.doc(listingId);
    final reservationReference = listingReference
        .collection('private')
        .doc('reservation');

    await _firestore.runTransaction<void>((transaction) async {
      final listingSnapshot = await transaction.get(listingReference);
      final reservationSnapshot = await transaction.get(reservationReference);
      final listing = listingSnapshot.data();
      final reservation = reservationSnapshot.data();
      if (!listingSnapshot.exists ||
          listing == null ||
          !reservationSnapshot.exists ||
          reservation == null ||
          listing['status'] != 'reserved') {
        throw StateError('The reservation is no longer active.');
      }
      if (_isConfirmed(reservation)) {
        throw StateError('The handover has already been confirmed.');
      }
      if (requireReceiver
          ? reservation['receiverId'] != userId
          : listing['donorId'] != userId) {
        throw StateError('This reservation does not belong to this account.');
      }

      DocumentReference<Map<String, dynamic>>? slotReference;
      final receiverId = reservation['receiverId'];
      final slotId = reservation['slotId'];
      if (receiverId is String && slotId is String) {
        slotReference = _reservationSlot(receiverId, slotId);
      }

      transaction.update(listingReference, {'status': status});
      transaction.delete(reservationReference);
      if (slotReference != null) {
        transaction.delete(slotReference);
      }
    });
  }

  DocumentReference<Map<String, dynamic>> _reservationSlot(
    String userId,
    String slotId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('private')
        .doc('reservationSlots')
        .collection('slots')
        .doc(slotId);
  }

  bool _isExpired(Map<String, dynamic> reservation) {
    final now = DateTime.now().toUtc();
    if (reservation.containsKey('expiresAt')) {
      final expiresAt = reservation['expiresAt'];
      return expiresAt is Timestamp && !expiresAt.toDate().toUtc().isAfter(now);
    }

    final createdAt = reservation['createdAt'];
    return createdAt is Timestamp &&
        !createdAt.toDate().toUtc().add(const Duration(hours: 48)).isAfter(now);
  }

  bool _isConfirmed(Map<String, dynamic> reservation) {
    return reservation.containsKey('handoverToken') ||
        reservation.containsKey('confirmedAt');
  }

  @override
  Future<PickupCoordinates> getPickupCoordinates(String listingId) async {
    _validateListingId(listingId);
    _requireUser();
    final snapshot = await _listings
        .doc(listingId)
        .collection('private')
        .doc('pickup')
        .get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw StateError('Private pickup coordinates are missing.');
    }

    final latitude = data['latitude'];
    final longitude = data['longitude'];
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

  @override
  Future<HandoverQrPayload> issueHandoverCode(String listingId) async {
    _validateListingId(listingId);
    final user = _requireUser();
    final token = _generateToken();
    final listingReference = _listings.doc(listingId);
    final handoverReference = listingReference
        .collection('private')
        .doc('handover');

    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(listingReference);
      final listing = snapshot.data();
      if (!snapshot.exists || listing == null) {
        throw StateError('The listing no longer exists.');
      }
      if (listing['donorId'] != user.uid) {
        throw StateError('Only the donor can issue a handover code.');
      }
      if (listing['status'] != 'reserved') {
        throw StateError('A handover code requires a reserved listing.');
      }
      transaction.set(handoverReference, {
        'token': token,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    return HandoverQrPayload(listingId: listingId, token: token);
  }

  @override
  Future<void> confirmHandover(HandoverQrPayload payload) async {
    _validateListingId(payload.listingId);
    final user = _requireUser();
    final listingReference = _listings.doc(payload.listingId);
    final reservationReference = listingReference
        .collection('private')
        .doc('reservation');

    await _firestore.runTransaction<void>((transaction) async {
      final listingSnapshot = await transaction.get(listingReference);
      final reservationSnapshot = await transaction.get(reservationReference);
      final listing = listingSnapshot.data();
      final reservation = reservationSnapshot.data();
      if (!listingSnapshot.exists ||
          listing == null ||
          !reservationSnapshot.exists ||
          reservation == null) {
        throw StateError('The reservation is no longer active.');
      }
      if (listing['status'] != 'reserved' ||
          reservation['receiverId'] != user.uid) {
        throw StateError('This reservation does not belong to this account.');
      }
      final slotId = reservation['slotId'];
      if (slotId is! String) {
        throw StateError('The reservation slot is missing.');
      }
      final slotReference = _reservationSlot(user.uid, slotId);
      final slotSnapshot = await transaction.get(slotReference);
      if (!slotSnapshot.exists ||
          slotSnapshot.data()?['listingId'] != payload.listingId) {
        throw StateError('The reservation slot is missing.');
      }

      transaction.update(reservationReference, {
        'handoverToken': payload.token,
        'confirmedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(listingReference, {'status': 'handedOver'});
      transaction.delete(slotReference);
    });
  }

  User _requireUser() {
    return _auth.currentUser ?? (throw const AuthenticationRequiredException());
  }

  String _generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  void _validateListingId(String listingId) {
    if (!_listingIdPattern.hasMatch(listingId)) {
      throw ArgumentError.value(
        listingId,
        'listingId',
        'Must be a valid Firestore document id.',
      );
    }
  }
}
