import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapis/application/listing_providers.dart';
import 'package:kapis/domain/models/handover_qr_payload.dart';
import 'package:kapis/domain/models/listing.dart';
import 'package:kapis/domain/models/pickup_coordinates.dart';
import 'package:kapis/domain/models/user_account.dart';
import 'package:kapis/domain/repositories/handover_repository.dart';
import 'package:kapis/domain/repositories/listing_report_repository.dart';
import 'package:kapis/features/auth/presentation/auth_screen.dart';
import 'package:kapis/features/listings/presentation/listing_discovery_screen.dart';
import 'package:kapis/firebase/firebase_providers.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('a submitted report hides the listing for this session', (
    tester,
  ) async {
    final reports = _FakeListingReportRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(_account('receiver-1')),
          ),
          availableListingsProvider(null)
              .overrideWith((ref) => Stream.value([_listing()])),
          listingReportRepositoryProvider.overrideWith((ref) async => reports),
        ],
        child: const MaterialApp(home: ListingDiscoveryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('İlanı bildir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spam veya yanıltıcı ilan'));
    await tester.pumpAndSettle();

    expect(reports.reportedListingId, _listing().id);
    expect(reports.reason, ListingReportReason.spam);
    expect(find.text('Masa'), findsNothing);
    expect(
      find.text('Bildirim alındı; bu ilan sana gösterilmeyecek.'),
      findsOneWidget,
    );
  });

  testWidgets('requires confirmation before reserving another donor listing', (
    tester,
  ) async {
    final repository = _FakeHandoverRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(_account('receiver-1')),
          ),
          availableListingsProvider(null)
              .overrideWith((ref) => Stream.value([_listing()])),
          handoverRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: const MaterialApp(home: ListingDiscoveryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ayırt ve teslim al'));
    await tester.tap(find.text('Ayırt ve teslim al'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('bağışçının kesin teslim noktası'),
      findsOneWidget,
    );
    expect(repository.reservedListingId, isNull);
    await tester.tap(find.text('Ayırt ve devam et'));
    await tester.pump();

    expect(repository.reservedListingId, _listing().id);
  });

  testWidgets('requires account sign-in before discovery', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          availableListingsProvider(null)
              .overrideWith((ref) => Stream.value([_listing()])),
          handoverRepositoryProvider.overrideWith(
            (ref) async => _FakeHandoverRepository(),
          ),
        ],
        child: const MaterialApp(home: ListingDiscoveryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Bağışları keşfetmek için hesabına giriş yap.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);
  });

  testWidgets('does not show a reserve button on your own listing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(_account('donor-1')),
          ),
          availableListingsProvider(null)
              .overrideWith((ref) => Stream.value([_listing()])),
        ],
        child: const MaterialApp(home: ListingDiscoveryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bu senin ilanındır.'), findsOneWidget);
    expect(find.text('Ayırt ve teslim al'), findsNothing);
  });
}

UserAccount _account(String id) {
  return UserAccount(id: id, email: '$id@example.com', emailVerified: true);
}

Listing _listing() {
  return Listing(
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
}

final class _FakeHandoverRepository implements HandoverRepository {
  String? reservedListingId;

  @override
  Future<void> cancelReservation(String listingId) async {}

  @override
  Future<void> confirmHandover(HandoverQrPayload payload) async {}

  @override
  Future<PickupCoordinates> getPickupCoordinates(String listingId) async {
    return PickupCoordinates(latitude: 41.001, longitude: 29.001);
  }

  @override
  Future<HandoverQrPayload> issueHandoverCode(String listingId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> releaseReservation(
    String listingId, {
    bool withdraw = false,
  }) async {}

  @override
  Future<void> reserveListing(String listingId) async {
    reservedListingId = listingId;
  }

  @override
  Stream<List<Listing>> watchMyReservations() => Stream.value(const []);

  @override
  Stream<ListingStatus?> watchListingStatus(String listingId) =>
      Stream.value(ListingStatus.reserved);
}

final class _FakeListingReportRepository implements ListingReportRepository {
  String? reportedListingId;
  ListingReportReason? reason;

  @override
  Future<void> reportListing({
    required String listingId,
    required ListingReportReason reason,
  }) async {
    reportedListingId = listingId;
    this.reason = reason;
  }
}
