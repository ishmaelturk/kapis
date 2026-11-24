import '../models/listing.dart';

abstract interface class ListingRepository {
  Future<void> create(Listing listing);

  Future<Listing?> findById(String id);
}
