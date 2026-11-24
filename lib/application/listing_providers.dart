import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/listing.dart';
import '../firebase/firebase_providers.dart';

final availableListingsProvider = StreamProvider.autoDispose
    .family<List<Listing>, String?>((ref, area) async* {
      final repository = await ref.watch(listingRepositoryProvider.future);
      yield* repository.watchAvailable(pickupArea: area);
    });

final myListingsProvider = StreamProvider.autoDispose<List<Listing>>((
  ref,
) async* {
  final repository = await ref.watch(listingRepositoryProvider.future);
  yield* repository.watchMyListings();
});
