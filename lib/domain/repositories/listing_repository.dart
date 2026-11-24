import '../models/listing.dart';
import '../models/pickup_coordinates.dart';

abstract interface class ListingRepository {
  Future<void> create(
    Listing listing, {
    required PickupCoordinates pickupCoordinates,
  });

  Stream<List<Listing>> watchAvailable({String? pickupArea, int limit = 30});

  Future<Listing?> findById(String id);

  Future<PickupCoordinates> getPickupCoordinatesForHandover(String listingId);
}
