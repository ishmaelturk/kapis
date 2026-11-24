import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/listing.dart';
import '../firebase/firebase_providers.dart';

final availableListingsProvider = StreamProvider.autoDispose
    .family<List<Listing>, String?>((ref, area) async* {
      final authState = ref.watch(authStateProvider);
      if (authState.hasError) {
        Error.throwWithStackTrace(authState.error!, authState.stackTrace!);
      }
      if (!authState.hasValue || authState.value == null) {
        yield const <Listing>[];
        return;
      }
      final repository = await ref.watch(listingRepositoryProvider.future);
      yield* repository.watchAvailable(pickupArea: area);
    });

final myListingsProvider = StreamProvider.autoDispose<List<Listing>>((ref) {
  final authState = ref.watch(authStateProvider);
  if (authState.hasError) {
    return Stream.error(authState.error!, authState.stackTrace!);
  }
  if (!authState.hasValue || authState.value == null) {
    return Stream.value(const <Listing>[]);
  }
  return ref
      .watch(listingRepositoryProvider.future)
      .asStream()
      .asyncExpand((repository) => repository.watchMyListings());
});

final myReservationsProvider = StreamProvider.autoDispose<List<Listing>>((ref) {
  final authState = ref.watch(authStateProvider);
  if (authState.hasError) {
    return Stream.error(authState.error!, authState.stackTrace!);
  }
  if (!authState.hasValue || authState.value == null) {
    return Stream.value(const <Listing>[]);
  }
  return ref
      .watch(handoverRepositoryProvider.future)
      .asStream()
      .asyncExpand((repository) => repository.watchMyReservations());
});
