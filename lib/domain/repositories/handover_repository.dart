import '../models/handover_qr_payload.dart';
import '../models/listing.dart';
import '../models/pickup_coordinates.dart';

abstract interface class HandoverRepository {
  Future<void> reserveListing(String listingId);

  Future<void> cancelReservation(String listingId);

  Future<void> releaseReservation(String listingId, {bool withdraw = false});

  Stream<List<Listing>> watchMyReservations();

  Stream<ListingStatus?> watchListingStatus(String listingId);

  Future<PickupCoordinates> getPickupCoordinates(String listingId);

  Future<HandoverQrPayload> issueHandoverCode(String listingId);

  Future<void> confirmHandover(HandoverQrPayload payload);
}
