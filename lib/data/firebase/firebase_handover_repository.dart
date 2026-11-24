import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/handover_qr_payload.dart';
import '../../domain/models/pickup_coordinates.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/handover_repository.dart';

final class FirebaseHandoverRepository implements HandoverRepository {
  FirebaseHandoverRepository(this._firestore, this._auth);

  static final _listingIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

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

    await _firestore.runTransaction<void>((transaction) async {
      final listingSnapshot = await transaction.get(listingReference);
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

      transaction.update(listingReference, {'status': 'reserved'});
      transaction.set(reservationReference, {
        'receiverId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
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

      transaction.update(reservationReference, {
        'handoverToken': payload.token,
        'confirmedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(listingReference, {'status': 'handedOver'});
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
