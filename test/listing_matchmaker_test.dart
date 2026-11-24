import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kapis/data/firebase/firebase_listing_matchmaker.dart';
import 'package:kapis/domain/models/listing.dart';
import 'package:kapis/domain/models/listing_match.dart';
import 'package:kapis/domain/models/pickup_coordinates.dart';
import 'package:kapis/domain/services/turkish_text_normalizer.dart';

void main() {
  test('normalizes Turkish dotted and dotless I before token matching', () {
    expect(normalizeTurkishText('İstanbul'), 'istanbul');
    expect(normalizeTurkishText('IĞDIR'), 'igdir');
    expect(normalizeTurkishText(' Kadıköy '), 'kadikoy');
  });

  test(
    'listing suggestion parses bounded fields and supports an optional photo',
    () async {
      Content? receivedContent;
      final matchmaker = FirebaseListingMatchmaker((content) async {
        receivedContent = content;
        return jsonEncode({
          'title': 'Çalışma masası',
          'description': 'Sağlam masa, elden teslim.',
          'category': 'tablesAndDesks',
          'tags': ['masa', 'çalışma'],
        });
      });

      final result = await matchmaker.suggestListing(
        title: 'Masa',
        notes: 'Kullanılmış ama sağlam.',
        photo: ListingMatchPhoto(
          bytes: Uint8List.fromList([1, 2, 3]),
          mimeType: 'image/jpeg',
        ),
      );

      expect(result.usedFallback, isFalse);
      expect(result.suggestion.category, ListingCategory.tablesAndDesks);
      expect(result.suggestion.tags, ['masa', 'çalışma']);
      expect(receivedContent!.parts.whereType<InlineDataPart>(), hasLength(1));
    },
  );

  test('invalid AI suggestion falls back to local listing text', () async {
    final matchmaker = FirebaseListingMatchmaker(
      (_) async => '{"title": "ok", "description": "ok", "category": "bad"}',
    );

    final result = await matchmaker.suggestListing(
      title: 'Masa',
      notes: 'Çalışma masası sağlam.',
    );

    expect(result.usedFallback, isTrue);
    expect(result.fallbackReason, MatchFallbackReason.invalidResponse);
    expect(result.suggestion.title, 'Masa');
    expect(result.suggestion.category, ListingCategory.tablesAndDesks);
  });

  test(
    'Firebase AI service errors fall back without losing donor input',
    () async {
      final matchmaker = FirebaseListingMatchmaker(
        (_) async => throw FirebaseAIException('quota exceeded'),
      );

      final result = await matchmaker.suggestListing(
        title: 'Lamba',
        notes: 'Çalışır durumda.',
      );

      expect(result.usedFallback, isTrue);
      expect(result.fallbackReason, MatchFallbackReason.serviceUnavailable);
      expect(result.suggestion.description, 'Çalışır durumda.');
    },
  );

  test(
    'socket and HTTP client errors use local suggestion and ranking',
    () async {
      for (final error in <Object>[
        const SocketException('offline'),
        http.ClientException('offline'),
      ]) {
        final matchmaker = FirebaseListingMatchmaker((_) async => throw error);
        final suggestion = await matchmaker.suggestListing(
          title: 'Masa',
          notes: 'Çalışma masası.',
        );
        final ranking = await matchmaker.rankListings(
          receiverNeeds: 'masa',
          candidates: [
            _listing(
              id: 'desk',
              title: 'Çalışma masası',
              description: 'Ahşap masa',
            ),
          ],
        );

        expect(
          suggestion.fallbackReason,
          MatchFallbackReason.serviceUnavailable,
        );
        expect(ranking.fallbackReason, MatchFallbackReason.serviceUnavailable);
      }
    },
  );

  test('timed out AI calls use deterministic matching', () async {
    final pendingResponse = Completer<String>();
    final matchmaker = FirebaseListingMatchmaker(
      (_) => pendingResponse.future,
      requestTimeout: const Duration(milliseconds: 1),
    );
    final candidates = [
      _listing(id: 'desk', title: 'Çalışma masası', description: 'Ahşap masa'),
      _listing(id: 'lamp', title: 'Masa lambası', description: 'Aydınlatma'),
    ];

    final result = await matchmaker.rankListings(
      receiverNeeds: 'çalışma masası',
      candidates: candidates,
    );

    expect(result.fallbackReason, MatchFallbackReason.timeout);
    expect(result.matches.first.listingId, 'desk');
    expect(result.matches.first.score, 100);
  });

  test(
    'AI ranking is capped at 15 and only receives public listing fields',
    () async {
      String? prompt;
      final candidates = [
        for (var index = 0; index < 17; index++)
          _listing(
            id: 'listing_$index',
            title: 'Masa $index',
            description: 'Ahşap çalışma masası',
          ),
      ];
      final matchmaker = FirebaseListingMatchmaker((content) async {
        prompt = content.parts.whereType<TextPart>().single.text;
        return jsonEncode({
          'matches': [
            for (var index = 0; index < 15; index++)
              {
                'index': 14 - index,
                'score': 100 - index,
                'reason': 'Eşleşiyor.',
              },
          ],
        });
      });

      final result = await matchmaker.rankListings(
        receiverNeeds: 'çalışma masası',
        candidates: candidates,
      );

      expect(result.matches, hasLength(15));
      expect(result.matches.first.listingId, 'listing_14');
      expect(prompt, isNot(contains('pickupArea')));
      expect(prompt, isNot(contains('latitude')));
      expect(prompt, isNot(contains('donorId')));
    },
  );

  test(
    'malformed candidate ranking falls back to deterministic scores',
    () async {
      final matchmaker = FirebaseListingMatchmaker(
        (_) async => '{"matches":[{"index":0,"score":101,"reason":"bad"}]}',
      );
      final result = await matchmaker.rankListings(
        receiverNeeds: 'masa',
        candidates: [
          _listing(id: 'desk', title: 'Masa', description: 'Ahşap'),
          _listing(id: 'lamp', title: 'Lamba', description: 'Aydınlatma'),
        ],
      );

      expect(result.fallbackReason, MatchFallbackReason.invalidResponse);
      expect(result.matches.first.listingId, 'desk');
      expect(result.matches.first.score, 100);
    },
  );
}

Listing _listing({
  required String id,
  required String title,
  required String description,
}) {
  return Listing(
    id: id,
    donorId: 'donor',
    title: title,
    description: description,
    pickupArea: 'Kadıköy',
    category: ListingCategory.householdGoods,
    condition: ItemCondition.good,
    tags: const [],
    approximateMapCoordinates: PickupCoordinates(
      latitude: 41.0,
      longitude: 29.0,
    ),
    createdAt: DateTime.utc(2026),
  );
}
