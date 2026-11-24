import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapis/domain/models/handover_qr_payload.dart';
import 'package:kapis/domain/models/listing.dart';
import 'package:kapis/domain/models/pickup_coordinates.dart';
import 'package:kapis/domain/models/user_account.dart';
import 'package:kapis/domain/repositories/auth_repository.dart';
import 'package:kapis/domain/repositories/handover_repository.dart';
import 'package:kapis/domain/repositories/listing_repository.dart';
import 'package:kapis/features/auth/presentation/auth_screen.dart';
import 'package:kapis/firebase/firebase_providers.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('validates email format before authentication', (tester) async {
    final auth = _FakeAuthRepository();
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.text('Giriş yap').last);
    await tester.pumpAndSettle();

    expect(find.text('Geçerli bir e-posta adresi gir.'), findsOneWidget);
    expect(auth.signInCount, 0);
  });

  testWidgets('requires eight characters when creating an account', (
    tester,
  ) async {
    final auth = _FakeAuthRepository();
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hesabın yok mu? Oluştur'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'short7');
    await tester.tap(find.text('Hesap oluştur').last);
    await tester.pumpAndSettle();

    expect(find.text('Şifren en az 8 karakter olmalı.'), findsOneWidget);
    expect(auth.createCount, 0);
  });

  testWidgets('account creation links to the privacy and terms page', (
    tester,
  ) async {
    final auth = _FakeAuthRepository();
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hesabın yok mu? Oluştur'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gizlilik ve kullanım koşullarını oku'));
    await tester.pumpAndSettle();

    expect(find.text('Gizlilik bildirimi'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Kullanım koşulları'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Kullanım koşulları'), findsOneWidget);
  });

  testWidgets('sends password reset to the entered email', (tester) async {
    final auth = _FakeAuthRepository();
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'user@example.com',
    );
    await tester.tap(find.text('Şifremi unuttum'));
    await tester.pumpAndSettle();

    expect(auth.resetEmail, 'user@example.com');
    expect(
      find.text('Şifre yenileme bağlantısı e-posta adresine gönderildi.'),
      findsOneWidget,
    );
  });

  testWidgets('withdraws listings and releases reservations before deletion', (
    tester,
  ) async {
    final auth = _FakeAuthRepository(account: _account);
    final listings = _FakeListingRepository();
    final handovers = _FakeHandoverRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWith((ref) async => auth),
          listingRepositoryProvider.overrideWith((ref) async => listings),
          handoverRepositoryProvider.overrideWith((ref) async => handovers),
        ],
        child: const MaterialApp(home: AuthScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hesabımı sil').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hesabımı sil').last);
    await tester.pumpAndSettle();

    expect(listings.withdrawnListingIds, ['available-1']);
    expect(handovers.releasedListingIds, ['reserved-1']);
    expect(handovers.cancelledListingIds, ['receiver-reservation-1']);
    expect(auth.deleted, isTrue);
  });
}

Widget _app(_FakeAuthRepository auth) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWith((ref) async => auth)],
    child: const MaterialApp(home: AuthScreen()),
  );
}

const _account = UserAccount(
  id: 'user-1',
  email: 'user@example.com',
  emailVerified: true,
);

final _availableListing = _listing('available-1', ListingStatus.available);
final _reservedListing = _listing('reserved-1', ListingStatus.reserved);
final _receiverReservation = _listing(
  'receiver-reservation-1',
  ListingStatus.reserved,
);

Listing _listing(String id, ListingStatus status) {
  return Listing(
    id: id,
    donorId: 'user-1',
    title: 'Masa',
    description: 'Sağlam masa',
    pickupArea: 'Kadıköy',
    category: ListingCategory.tablesAndDesks,
    condition: ItemCondition.good,
    tags: const [],
    approximateMapCoordinates: PickupCoordinates(latitude: 41, longitude: 29),
    createdAt: DateTime.utc(2025),
    status: status,
  );
}

final class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this._account});

  final UserAccount? _account;
  String? resetEmail;
  int signInCount = 0;
  int createCount = 0;
  bool deleted = false;

  @override
  Future<UserAccount> createAccount({
    required String email,
    required String password,
  }) async {
    createCount++;
    return _account ?? _accountFallback;
  }

  @override
  Future<UserAccount> signIn({
    required String email,
    required String password,
  }) async {
    signInCount++;
    return _account ?? _accountFallback;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    resetEmail = email;
  }

  @override
  Future<void> deleteAccount() async {
    deleted = true;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> requestStudentEmailVerification() async {}

  @override
  Future<bool> refreshStudentVerification() async => true;

  @override
  Stream<UserAccount?> watchUser() => Stream.value(_account);
}

const _accountFallback = UserAccount(
  id: 'fallback',
  email: 'fallback@example.com',
  emailVerified: false,
);

final class _FakeListingRepository implements ListingRepository {
  final withdrawnListingIds = <String>[];

  @override
  Future<Listing> create(
    ListingDraft draft, {
    required PickupCoordinates pickupCoordinates,
  }) async => _availableListing;

  @override
  Future<List<Listing>> getAllMyListings() async => [
    _availableListing,
    _reservedListing,
  ];

  @override
  Future<Listing?> findById(String id) async => null;

  @override
  Future<Listing> update(
    String listingId,
    ListingDraft draft, {
    required PickupCoordinates pickupCoordinates,
  }) async => _availableListing;

  @override
  Future<void> updateImagePaths(
    String listingId,
    List<String> imagePaths,
  ) async {}

  @override
  Future<void> withdraw(String listingId) async {
    withdrawnListingIds.add(listingId);
  }

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
      Stream.value([_availableListing, _reservedListing]);
}

final class _FakeHandoverRepository implements HandoverRepository {
  final releasedListingIds = <String>[];
  final cancelledListingIds = <String>[];

  @override
  Future<void> cancelReservation(String listingId) async {
    cancelledListingIds.add(listingId);
  }

  @override
  Future<void> confirmHandover(HandoverQrPayload payload) async {}

  @override
  Future<PickupCoordinates> getPickupCoordinates(String listingId) async =>
      PickupCoordinates(latitude: 41, longitude: 29);

  @override
  Future<HandoverQrPayload> issueHandoverCode(String listingId) async =>
      throw UnimplementedError();

  @override
  Future<void> releaseReservation(
    String listingId, {
    bool withdraw = false,
  }) async {
    releasedListingIds.add(listingId);
  }

  @override
  Future<void> reserveListing(String listingId) async {}

  @override
  Stream<List<Listing>> watchMyReservations() =>
      Stream.value([_receiverReservation]);

  @override
  Stream<ListingStatus?> watchListingStatus(String listingId) =>
      Stream.value(ListingStatus.reserved);
}
