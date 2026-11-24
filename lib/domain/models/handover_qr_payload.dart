final class HandoverQrPayload {
  static final _listingIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static final _tokenPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');

  factory HandoverQrPayload({
    required String listingId,
    required String token,
  }) {
    if (!_listingIdPattern.hasMatch(listingId) ||
        !_tokenPattern.hasMatch(token)) {
      throw ArgumentError('Invalid handover QR payload.');
    }
    return HandoverQrPayload._(listingId, token);
  }

  const HandoverQrPayload._(this.listingId, this.token);

  final String listingId;
  final String token;

  factory HandoverQrPayload.parse(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'kapis' ||
        uri.host != 'handover' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.pathSegments.length != 2) {
      throw const FormatException('Invalid Kapış handover QR code.');
    }

    final listingId = uri.pathSegments[0];
    final token = uri.pathSegments[1];
    if (!_listingIdPattern.hasMatch(listingId) ||
        !_tokenPattern.hasMatch(token)) {
      throw const FormatException('Invalid Kapış handover QR code.');
    }
    return HandoverQrPayload(listingId: listingId, token: token);
  }

  @override
  String toString() => 'kapis://handover/$listingId/$token';
}
