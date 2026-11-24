import '../models/handover_qr_payload.dart';
import '../models/pickup_coordinates.dart';

abstract interface class HandoverRepository {
  Future<void> reserveListing(String listingId);

  Future<PickupCoordinates> getPickupCoordinates(String listingId);

  Future<HandoverQrPayload> issueHandoverCode(String listingId);

  Future<void> confirmHandover(HandoverQrPayload payload);
}
