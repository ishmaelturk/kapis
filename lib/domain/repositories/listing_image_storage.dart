import 'dart:typed_data';

abstract interface class ListingImageStorage {
  Future<String> uploadImage({
    required String listingId,
    required String imageId,
    required Uint8List bytes,
    required String contentType,
  });

  Future<void> deleteImage({required String path});

  Future<String> getDownloadUrl(String path);
}
