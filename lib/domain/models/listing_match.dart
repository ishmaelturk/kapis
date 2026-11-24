import 'dart:typed_data';

import 'listing.dart';

enum MatchFallbackReason {
  timeout,
  invalidResponse,
  serviceUnavailable,
  notConfigured,
}

final class ListingMatchPhoto {
  const ListingMatchPhoto({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

final class ListingDraftSuggestion {
  ListingDraftSuggestion({
    required this.title,
    required this.description,
    required this.category,
    required List<String> tags,
  }) : tags = List.unmodifiable(tags) {
    if (title.trim().isEmpty || title.length > 100) {
      throw ArgumentError.value(
        title,
        'title',
        'Must contain 1-100 characters.',
      );
    }
    if (description.trim().isEmpty || description.length > 1000) {
      throw ArgumentError.value(
        description,
        'description',
        'Must contain 1-1000 characters.',
      );
    }
    if (this.tags.length > 10 ||
        this.tags.any((tag) => tag.trim().isEmpty || tag.length > 32)) {
      throw ArgumentError.value(
        tags,
        'tags',
        'Use at most 10 non-blank tags of at most 32 characters.',
      );
    }
  }

  final String title;
  final String description;
  final ListingCategory category;
  final List<String> tags;
}

final class ListingMatch {
  const ListingMatch({
    required this.listingId,
    required this.score,
    required this.reason,
  }) : assert(score >= 0 && score <= 100);

  final String listingId;
  final int score;
  final String reason;
}

final class ListingSuggestionResult {
  const ListingSuggestionResult({
    required this.suggestion,
    this.fallbackReason,
  });

  final ListingDraftSuggestion suggestion;
  final MatchFallbackReason? fallbackReason;

  bool get usedFallback => fallbackReason != null;
}

final class ListingMatchResult {
  ListingMatchResult({required List<ListingMatch> matches, this.fallbackReason})
    : matches = List.unmodifiable(matches);

  final List<ListingMatch> matches;
  final MatchFallbackReason? fallbackReason;

  bool get usedFallback => fallbackReason != null;
}
