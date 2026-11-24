import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/listing.dart';
import '../../domain/models/pickup_coordinates.dart';
import '../../domain/services/turkish_text_normalizer.dart';

final class ListingFirestoreMapper {
  const ListingFirestoreMapper();

  Map<String, Object?> toDocument(Listing listing) {
    return {
      'donorId': listing.donorId,
      'title': listing.title,
      'description': listing.description,
      'pickupArea': listing.pickupArea,
      'pickupAreaKey': listing.pickupAreaKey,
      'category': listing.category.name,
      'condition': listing.condition.name,
      'tags': listing.tags,
      'imagePaths': listing.imagePaths,
      'approximateLatitude': listing.approximateMapCoordinates.latitude,
      'approximateLongitude': listing.approximateMapCoordinates.longitude,
      'status': listing.status.name,
      'createdAt': Timestamp.fromDate(listing.createdAt.toUtc()),
    };
  }

  Listing fromDocument(String id, Map<String, dynamic> document) {
    if (document.containsKey('pickupCoordinates')) {
      throw const FormatException(
        'Exact pickup coordinates must not be stored in public listing data.',
      );
    }

    final tagsValue = document['tags'];
    if (tagsValue is! List || tagsValue.any((tag) => tag is! String)) {
      throw const FormatException('Listing tags are invalid.');
    }
    final imagePathsValue = document['imagePaths'] ?? const <Object?>[];
    if (imagePathsValue is! List ||
        imagePathsValue.any((path) => path is! String)) {
      throw const FormatException('Listing images are invalid.');
    }
    final createdAtValue = document['createdAt'];
    if (createdAtValue is! Timestamp) {
      throw const FormatException('Listing creation time is invalid.');
    }
    final latitude = document['approximateLatitude'];
    final longitude = document['approximateLongitude'];
    final pickupArea = _requiredString(document, 'pickupArea');
    final pickupAreaKey = document['pickupAreaKey'];
    if (pickupAreaKey != null &&
        (pickupAreaKey is! String ||
            pickupAreaKey != normalizeTurkishText(pickupArea))) {
      throw const FormatException('Listing pickup area key is invalid.');
    }
    if (latitude is! num || longitude is! num) {
      throw const FormatException('Approximate map coordinates are invalid.');
    }

    return Listing(
      id: id,
      donorId: _requiredString(document, 'donorId'),
      title: _requiredString(document, 'title'),
      description: _requiredString(document, 'description'),
      pickupArea: pickupArea,
      category: _enumFromName(
        ListingCategory.values,
        document['category'],
        'category',
      ),
      condition: _enumFromName(
        ItemCondition.values,
        document['condition'],
        'condition',
      ),
      tags: List<String>.from(tagsValue),
      imagePaths: List<String>.from(imagePathsValue),
      approximateMapCoordinates: PickupCoordinates(
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
      ),
      status: _enumFromName(ListingStatus.values, document['status'], 'status'),
      createdAt: createdAtValue.toDate().toUtc(),
    );
  }

  List<Listing> fromDocuments(
    Iterable<({String id, Map<String, dynamic> data})> documents,
  ) {
    final listings = <Listing>[];
    for (final document in documents) {
      try {
        listings.add(fromDocument(document.id, document.data));
      } on FormatException catch (error, stackTrace) {
        _logInvalidDocument(document.id, error, stackTrace);
      } on ArgumentError catch (error, stackTrace) {
        _logInvalidDocument(document.id, error, stackTrace);
      }
    }
    return List.unmodifiable(listings);
  }

  void _logInvalidDocument(String id, Object error, StackTrace stackTrace) {
    log(
      'Skipping invalid listing document "$id".',
      name: 'ListingFirestoreMapper',
      error: error,
      stackTrace: stackTrace,
    );
  }

  String _requiredString(Map<String, dynamic> document, String field) {
    final value = document[field];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Listing field "$field" is missing or invalid.');
    }
    return value;
  }

  T _enumFromName<T extends Enum>(List<T> values, Object? name, String field) {
    if (name is String) {
      for (final value in values) {
        if (value.name == name) {
          return value;
        }
      }
    }
    throw FormatException('Listing field "$field" has an unknown value.');
  }
}
