import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../domain/repositories/listing_image_storage.dart';

final class FirebaseListingImageStorage implements ListingImageStorage {
  FirebaseListingImageStorage(this._storage);

  static const _maximumImageBytes = 10 * 1024 * 1024;
  static const _allowedContentTypes = {'image/jpeg', 'image/png', 'image/webp'};
  static final _pathSegmentPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

  final FirebaseStorage _storage;

  @override
  Future<String> uploadImage({
    required String listingId,
    required String imageId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    _validatePathSegment(listingId, 'listingId');
    _validatePathSegment(imageId, 'imageId');
    if (bytes.isEmpty || bytes.length > _maximumImageBytes) {
      throw ArgumentError.value(
        bytes.length,
        'bytes',
        'Image size must be between 1 byte and 10 MiB.',
      );
    }
    if (!_allowedContentTypes.contains(contentType)) {
      throw ArgumentError.value(
        contentType,
        'contentType',
        'Only JPEG, PNG, and WebP images are supported.',
      );
    }

    final path = 'listing-images/$listingId/$imageId';
    await _storage
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: contentType));
    return path;
  }

  @override
  Future<void> deleteImage({
    required String listingId,
    required String imageId,
  }) {
    _validatePathSegment(listingId, 'listingId');
    _validatePathSegment(imageId, 'imageId');
    return _storage.ref('listing-images/$listingId/$imageId').delete();
  }

  void _validatePathSegment(String value, String name) {
    if (!_pathSegmentPattern.hasMatch(value)) {
      throw ArgumentError.value(
        value,
        name,
        'Must contain 1-128 letters, digits, underscores, or hyphens.',
      );
    }
  }
}
