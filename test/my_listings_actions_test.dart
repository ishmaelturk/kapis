import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapis/application/listing_providers.dart';
import 'package:kapis/domain/models/handover_qr_payload.dart';
import 'package:kapis/domain/models/listing.dart';
import 'package:kapis/domain/models/pickup_coordinates.dart';
import 'package:kapis/domain/models/user_account.dart';
import 'package:kapis/domain/repositories/handover_repository.dart';
import 'package:kapis/domain/repositories/listing_repository.dart';
import 'package:kapis/features/listings/presentation/listing_form_screen.dart';
import 'package:kapis/features/listings/presentation/my_listings_screen.dart';
import 'package:kapis/firebase/firebase_providers.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('donor can edit an available listing from My Listings', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('İlan işlemleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Düzenle'));
    await tester.pumpAndSettle();

    expect(find.byType(ListingFormScreen), findsOneWidget);
    expect(find.text('İlanı düzenle'), findsOneWidget);
    final titleField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(titleField.controller?.text, 'Masa');
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('İlanı güncelle'), findsOneWidget);
  });

  testWidgets('withdrawal requires confirmation and reaches the repository', (
    tester,
  ) async {
    final repository = _FakeListingRepository();
    await tester.pumpWidget(_app(listingRepository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('İlan işlemleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yayından kaldır'));
    await tester.pumpAndSettle();
    expect(find.text('İlanı geri çek?'), findsOneWidget);
    expect(repository.withdrawnListingId, isNull);

    await tester.tap(find.text('İlanı geri çek').last);
    await tester.pumpAndSettle();
    expect(repository.withdrawnListingId, _listing.id);
  });
}

Widget _app({_FakeListingRepository? listingRepository}) {
  final handoverRepository = _FakeHandoverRepository();
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          const UserAccount(
            id: 'donor-1',
            email: 'donor@example.com',
            emailVerified: true,
          ),
        ),
      ),
      myListingsProvider.overrideWith((ref) => Stream.value([_listing])),
      listingRepositoryProvider.overrideWith(
        (ref) async => listingRepository ?? _FakeListingRepository(),
      ),
      handoverRepositoryProvider.overrideWith(
        (ref) async => handoverRepository,
      ),
    ],
    child: const MaterialApp(home: MyListingsScreen()),
  );
}

final _listing = Listing(
  id: 'listing-1',
  donorId: 'donor-1',
  title: 'Masa',
  description: 'Sağlam masa',
  pickupArea: 'Kadıköy',
  category: ListingCategory.tablesAndDesks,
  condition: ItemCondition.good,
  tags: const [],
  approximateMapCoordinates: PickupCoordinates(latitude: 41, longitude: 29),
  createdAt: DateTime.utc(2025),
);

final class _FakeListingRepository implements ListingRepository {
  String? withdrawnListingId;

  @override
  Future<Listing> create(
    ListingDraft draft, {
    required PickupCoordinates pickupCoordinates,
  }) async => throw UnimplementedError();

  @override
  Future<Listing?> findById(String id) async => _listing;

  @override
  Future<Listing> update(
    String listingId,
    ListingDraft draft, {
    required PickupCoordinates pickupCoordinates,
  }) async => _listing;

  @override
  Future<void> withdraw(String listingId) async {
    withdrawnListingId = listingId;
  }

  @override
  Future<void> updateImagePaths(
    String listingId,
    List<String> imagePaths,
  ) async {}

  @override
  Stream<List<Listing>> watchAvailable({String? pickupArea, int limit = 30}) =>
      Stream.value(const []);

  @override
  Future<List<Listing>> fetchAvailablePage({
    String? pickupArea,
    String? startAfterId,
    int limit = 30,
  }) async => const [];

  @override
  Stream<List<Listing>> watchMyListings({int limit = 100}) =>
      Stream.value([_listing]);

  @override
  Future<List<Listing>> getAllMyListings() async => [_listing];
}

final class _FakeHandoverRepository implements HandoverRepository {
  @override
  Future<void> cancelReservation(String listingId) async {}

  @override
  Future<void> confirmHandover(HandoverQrPayload payload) async {}

  @override
  Future<PickupCoordinates> getPickupCoordinates(String listingId) async =>
      PickupCoordinates(latitude: 41.001, longitude: 29.001);

  @override
  Future<HandoverQrPayload> issueHandoverCode(String listingId) async =>
      throw UnimplementedError();

  @override
  Future<void> releaseReservation(
    String listingId, {
    bool withdraw = false,
  }) async {}

  @override
  Future<void> reserveListing(String listingId) async {}

  @override
  Stream<List<Listing>> watchMyReservations() => Stream.value(const []);

  @override
  Stream<ListingStatus?> watchListingStatus(String listingId) =>
      Stream.value(ListingStatus.reserved);
}
