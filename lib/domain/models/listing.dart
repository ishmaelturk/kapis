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

enum ListingStatus { available, reserved, handedOver, withdrawn }

final class Listing {
  Listing({
    required this.id,
    required this.donorId,
    required this.title,
    required this.description,
    required this.pickupArea,
    required this.category,
    required this.condition,
    required List<String> tags,
    required this.createdAt,
    this.status = ListingStatus.available,
  }) : tags = List.unmodifiable(tags) {
    _requireNonBlank(id, 'id');
    _requireNonBlank(donorId, 'donorId');
    _requireLength(title, 'title', 100);
    _requireLength(description, 'description', 1000);
    _requireLength(pickupArea, 'pickupArea', 100);
    if (this.tags.length > 10 ||
        this.tags.any((tag) => tag.trim().isEmpty || tag.length > 32)) {
      throw ArgumentError.value(
        tags,
        'tags',
        'Use at most 10 non-blank tags of at most 32 characters.',
      );
    }
  }

  final String id;
  final String donorId;
  final String title;
  final String description;
  final String pickupArea;
  final ListingCategory category;
  final ItemCondition condition;
  final List<String> tags;
  final DateTime createdAt;
  final ListingStatus status;

  bool get isAvailable => status == ListingStatus.available;
}

void _requireNonBlank(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be blank.');
  }
}

void _requireLength(String value, String name, int maximumLength) {
  _requireNonBlank(value, name);
  if (value.length > maximumLength) {
    throw ArgumentError.value(
      value,
      name,
      'Must contain at most $maximumLength characters.',
    );
  }
}
