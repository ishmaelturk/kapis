import '../models/listing.dart';
import '../models/pickup_coordinates.dart';

abstract interface class ListingRepository {
  Future<Listing> create(
    ListingDraft draft, {
    required PickupCoordinates pickupCoordinates,
  });

  Future<Listing> update(
    String listingId,
    ListingDraft draft, {
    required PickupCoordinates pickupCoordinates,
  });

  Future<void> withdraw(String listingId);

  Future<void> updateImagePaths(String listingId, List<String> imagePaths);

  Stream<List<Listing>> watchAvailable({String? pickupArea, int limit = 30});

  Future<List<Listing>> fetchAvailablePage({
    String? pickupArea,
    String? startAfterId,
    int limit = 30,
  });

  Stream<List<Listing>> watchMyListings({int limit = 100});

  Future<List<Listing>> getAllMyListings();

  Future<Listing?> findById(String id);
}
