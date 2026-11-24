import 'pickup_coordinates.dart';

enum ListingCategory {
  furniture('Mobilya'),
  seating('Oturma'),
  tablesAndDesks('Masa ve çalışma'),
  lighting('Aydınlatma'),
  householdGoods('Ev eşyası'),
  other('Diğer');

  const ListingCategory(this.label);

  final String label;
}

enum ItemCondition {
  likeNew('Yeni gibi'),
  good('İyi'),
  fair('Kullanılmış ama sağlam');

  const ItemCondition(this.label);

  final String label;
}

enum ListingStatus {
  available,
  reserved,
  handedOver,
  withdrawn,
}

final class Listing {
  Listing({
    required this.id,
    required this.donorId,
    required this.title,
    required this.description,
    required this.category,
    required this.condition,
    required List<String> tags,
    required this.pickupCoordinates,
    required this.createdAt,
    this.status = ListingStatus.available,
  }) : tags = List.unmodifiable(tags) {
    _requireNonBlank(id, 'id');
    _requireNonBlank(donorId, 'donorId');
    _requireNonBlank(title, 'title');
    _requireNonBlank(description, 'description');
    if (this.tags.any((tag) => tag.trim().isEmpty)) {
      throw ArgumentError.value(tags, 'tags', 'Tags must not be blank.');
    }
  }

  final String id;
  final String donorId;
  final String title;
  final String description;
  final ListingCategory category;
  final ItemCondition condition;
  final List<String> tags;
  final PickupCoordinates pickupCoordinates;
  final DateTime createdAt;
  final ListingStatus status;

  bool get isAvailable => status == ListingStatus.available;
}

void _requireNonBlank(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be blank.');
  }
}
