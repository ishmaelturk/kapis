import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/listing.dart';
import '../../domain/models/pickup_coordinates.dart';

final class ListingFirestoreMapper {
  const ListingFirestoreMapper();

  Map<String, Object?> toDocument(Listing listing) {
    return {
      'donorId': listing.donorId,
      'title': listing.title,
      'description': listing.description,
      'pickupArea': listing.pickupArea,
      'category': listing.category.name,
      'condition': listing.condition.name,
      'tags': listing.tags,
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
    final createdAtValue = document['createdAt'];
    if (createdAtValue is! Timestamp) {
      throw const FormatException('Listing creation time is invalid.');
    }
    final latitude = document['approximateLatitude'];
    final longitude = document['approximateLongitude'];
    if (latitude is! num || longitude is! num) {
      throw const FormatException('Approximate map coordinates are invalid.');
    }

    return Listing(
      id: id,
      donorId: _requiredString(document, 'donorId'),
      title: _requiredString(document, 'title'),
      description: _requiredString(document, 'description'),
      pickupArea: _requiredString(document, 'pickupArea'),
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
      approximateMapCoordinates: PickupCoordinates(
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
      ),
      status: _enumFromName(ListingStatus.values, document['status'], 'status'),
      createdAt: createdAtValue.toDate().toUtc(),
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
