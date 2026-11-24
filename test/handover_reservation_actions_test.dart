import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapis/application/listing_providers.dart';
import 'package:kapis/domain/models/handover_qr_payload.dart';
import 'package:kapis/domain/models/listing.dart';
import 'package:kapis/domain/models/pickup_coordinates.dart';
import 'package:kapis/domain/models/user_account.dart';
import 'package:kapis/domain/repositories/handover_repository.dart';
import 'package:kapis/features/listings/handover/handover_screen.dart';
import 'package:kapis/features/listings/presentation/my_reservations_screen.dart';
import 'package:kapis/features/listings/presentation/pickup_map_view.dart';
import 'package:kapis/firebase/firebase_providers.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('receiver can confirm cancelling a reservation', (tester) async {
    final repository = _FakeHandoverRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          handoverRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: MaterialApp(
          home: HandoverScreen(
            listing: _reservedListing(),
            mode: HandoverMode.receiver,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(PickupMapView), findsOneWidget);
    await tester.tap(find.text('Ayırtmayı iptal et'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Ayırtman sona erecek ve ilan başka alıcılar için yeniden açılacak.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Ayırtmayı iptal et').last);
    await tester.pumpAndSettle();

    expect(repository.cancelledListingId, _reservedListing().id);
  });

  testWidgets('donor can release or withdraw a reservation', (tester) async {
    final repository = _FakeHandoverRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          handoverRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: MaterialApp(
          home: HandoverScreen(
            listing: _reservedListing(),
            mode: HandoverMode.donor,
          ),
        ),
      ),
    );

    await tester.tap(find.text('İlanı geri çek'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İlanı geri çek').last);
    await tester.pumpAndSettle();

    expect(repository.releasedListingId, _reservedListing().id);
    expect(repository.withdraw, isTrue);
  });

  testWidgets('donor sees delivery completion from listing updates', (
    tester,
  ) async {
    final statusController = StreamController<ListingStatus?>();
    addTearDown(statusController.close);
    final repository = _FakeHandoverRepository(
      statusStream: statusController.stream,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          handoverRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: MaterialApp(
          home: HandoverScreen(
            listing: _reservedListing(),
            mode: HandoverMode.donor,
          ),
        ),
      ),
    );
    await tester.pump();

    statusController.add(ListingStatus.handedOver);
    await tester.pumpAndSettle();

    expect(find.text('Teslim edildi. Bağış tamamlandı.'), findsOneWidget);
    expect(find.text('Devir QR kodu oluştur'), findsNothing);
  });

  testWidgets('receiver can reopen an active reservation from its list', (
    tester,
  ) async {
    final repository = _FakeHandoverRepository();
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
          myReservationsProvider.overrideWith(
            (ref) => Stream.value([_reservedListing()]),
          ),
          handoverRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: const MaterialApp(home: MyReservationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Teslimata devam et'));
    await tester.pumpAndSettle();

    expect(find.byType(HandoverScreen), findsOneWidget);
    expect(find.byType(PickupMapView), findsOneWidget);
  });
}

Listing _reservedListing() {
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
    status: ListingStatus.reserved,
  );
}

final class _FakeHandoverRepository implements HandoverRepository {
  _FakeHandoverRepository({this.statusStream});

  final Stream<ListingStatus?>? statusStream;

  String? cancelledListingId;
  String? releasedListingId;
  bool? withdraw;

  @override
  Future<void> cancelReservation(String listingId) async {
    cancelledListingId = listingId;
  }

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
  }) async {
    releasedListingId = listingId;
    this.withdraw = withdraw;
  }

  @override
  Stream<List<Listing>> watchMyReservations() => Stream.value(const []);

  @override
  Stream<ListingStatus?> watchListingStatus(String listingId) =>
      statusStream ?? Stream.value(ListingStatus.reserved);

  @override
  Future<void> reserveListing(String listingId) async {
    throw UnimplementedError();
  }
}
