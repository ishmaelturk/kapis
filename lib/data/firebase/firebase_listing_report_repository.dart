import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/listing_report_repository.dart';

final class FirebaseListingReportRepository implements ListingReportRepository {
  FirebaseListingReportRepository(this._firestore, this._auth);

  static final _listingIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Future<void> reportListing({
    required String listingId,
    required ListingReportReason reason,
  }) async {
    if (!_listingIdPattern.hasMatch(listingId)) {
      throw ArgumentError.value(listingId, 'listingId');
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthenticationRequiredException();
    }

    await _firestore.collection('reports').add({
      'listingId': listingId,
      'reporterId': user.uid,
      'reason': reason.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
