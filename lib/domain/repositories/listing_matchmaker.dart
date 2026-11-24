import '../models/listing.dart';
import '../models/listing_match.dart';

abstract interface class ListingMatchmaker {
  Future<ListingSuggestionResult> suggestListing({
    required String title,
    required String notes,
    ListingMatchPhoto? photo,
  });

  Future<ListingMatchResult> rankListings({
    required String receiverNeeds,
    required List<Listing> candidates,
  });
}
