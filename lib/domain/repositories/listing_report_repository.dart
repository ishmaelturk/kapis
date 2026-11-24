enum ListingReportReason {
  spam('Spam veya yanıltıcı ilan'),
  inappropriate('Uygunsuz içerik'),
  unsafe('Güvenli olmayan teslimat'),
  other('Diğer');

  const ListingReportReason(this.label);

  final String label;
}

abstract interface class ListingReportRepository {
  Future<void> reportListing({
    required String listingId,
    required ListingReportReason reason,
  });
}
