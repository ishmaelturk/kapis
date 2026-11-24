import '../models/listing.dart';
import '../models/pickup_coordinates.dart';

abstract interface class ListingRepository {
  Future<Listing> create(
    ListingDraft draft, {
    required PickupCoordinates pickupCoordinates,
  });

  Stream<List<Listing>> watchAvailable({String? pickupArea, int limit = 30});

  Stream<List<Listing>> watchMyListings({int limit = 100});

  Future<Listing?> findById(String id);
}
