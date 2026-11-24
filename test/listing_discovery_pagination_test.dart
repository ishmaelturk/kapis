import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapis/application/listing_providers.dart';
import 'package:kapis/domain/models/listing.dart';
import 'package:kapis/domain/models/pickup_coordinates.dart';
import 'package:kapis/domain/models/user_account.dart';
import 'package:kapis/domain/repositories/listing_repository.dart';
import 'package:kapis/features/listings/presentation/listing_discovery_screen.dart';
import 'package:kapis/firebase/firebase_providers.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('loads another bounded discovery page after the first 30', (
    tester,
  ) async {
    final firstPage = [
      for (var index = 0; index < 30; index++) _listing('listing-$index'),
    ];
    final nextPage = [_listing('listing-30'), _listing('listing-31')];
    final repository = _FakeListingRepository(nextPage);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              const UserAccount(
                id: 'receiver-1',
                email: 'receiver@example.com',
                emailVerified: true,
              ),
            ),
          ),
          availableListingsProvider(null)
              .overrideWith((ref) => Stream.value(firstPage)),
          listingRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: const MaterialApp(home: ListingDiscoveryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -20000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daha fazla ilan yükle'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(repository.requestedAfterId, 'listing-29');
    expect(find.text('Masa listing-30'), findsOneWidget);
    expect(find.text('Masa listing-31'), findsOneWidget);
  });
}

Listing _listing(String id) {
  return Listing(
    id: id,
    donorId: 'donor-1',
    title: 'Masa $id',
    description: 'Sağlam masa',
    pickupArea: 'Kadıköy',
    category: ListingCategory.tablesAndDesks,
    condition: ItemCondition.good,
    tags: const [],
    approximateMapCoordinates: PickupCoordinates(latitude: 41, longitude: 29),
    createdAt: DateTime.utc(2025),
  );
}

final class _FakeListingRepository implements ListingRepository {
  _FakeListingRepository(this.nextPage);

  final List<Listing> nextPage;
  String? requestedAfterId;

  @override
  Future<Listing> create(
    ListingDraft draft, {
    required PickupCoordinates pickupCoordinates,
  }) async => throw UnimplementedError();

  @override
  Future<List<Listing>> fetchAvailablePage({
    String? pickupArea,
    String? startAfterId,
    int limit = 30,
  }) async {
    requestedAfterId = startAfterId;
    return nextPage;
  }

  @override
  Future<List<Listing>> getAllMyListings() async => const [];

  @override
  Future<Listing?> findById(String id) async => null;

  @override
  Future<Listing> update(
    String listingId,
    ListingDraft draft, {
    required PickupCoordinates pickupCoordinates,
  }) async => throw UnimplementedError();

  @override
  Future<void> updateImagePaths(
    String listingId,
    List<String> imagePaths,
  ) async {}

  @override
  Future<void> withdraw(String listingId) async {}

  @override
  Stream<List<Listing>> watchAvailable({String? pickupArea, int limit = 30}) =>
      Stream.value(const []);

  @override
  Stream<List<Listing>> watchMyListings({int limit = 100}) =>
      Stream.value(const []);
}
