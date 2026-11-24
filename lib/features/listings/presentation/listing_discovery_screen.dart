import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../application/listing_providers.dart';
import '../../../domain/models/listing.dart';
import '../../../domain/models/listing_match.dart';
import '../../../domain/models/pickup_coordinates.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../firebase/firebase_providers.dart';
import '../../../firebase/firebase_runtime_config.dart';
import '../handover/handover_screen.dart';
import 'pickup_map_view.dart';

class ListingDiscoveryScreen extends ConsumerStatefulWidget {
  const ListingDiscoveryScreen({super.key});

  @override
  ConsumerState<ListingDiscoveryScreen> createState() =>
      _ListingDiscoveryScreenState();
}

class _ListingDiscoveryScreenState
    extends ConsumerState<ListingDiscoveryScreen> {
  final _areaController = TextEditingController();
  final _needsController = TextEditingController();
  String? _areaFilter;
  String? _actionError;
  ListingMatchResult? _matchResult;
  bool _isRanking = false;

  @override
  void dispose() {
    _areaController.dispose();
    _needsController.dispose();
    super.dispose();
  }

  Future<void> _rankListings(List<Listing> items) async {
    final needs = _needsController.text.trim();
    final areaFilter = _areaFilter;
    if (needs.isEmpty) {
      _setActionError('Önce aradığın eşya türünü kısaca yaz.');
      return;
    }
    setState(() {
      _isRanking = true;
      _actionError = null;
    });
    try {
      final result = await ref
          .read(listingMatchmakerProvider)
          .rankListings(receiverNeeds: needs, candidates: items);
      if (mounted) {
        if (_needsController.text.trim() == needs &&
            _areaFilter == areaFilter) {
          setState(() => _matchResult = result);
        }
      }
    } on ArgumentError catch (error) {
      _setActionError(
        error.message?.toString() ?? 'İhtiyaç notunu kontrol et.',
      );
    } on FirebaseConfigurationException catch (error) {
      _setActionError(error.toString());
    } on FirebaseAIException catch (error) {
      _setActionError(error.message);
    } on FirebaseAISdkException catch (error) {
      _setActionError(error.message);
    } on FirebaseException catch (error) {
      _setActionError(error.message ?? error.code);
    } finally {
      if (mounted) {
        setState(() => _isRanking = false);
      }
    }
  }

  Future<void> _reserve(Listing listing) async {
    setState(() => _actionError = null);
    try {
      final repository = await ref.read(handoverRepositoryProvider.future);
      await repository.reserveListing(listing.id);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              HandoverScreen(listing: listing, mode: HandoverMode.receiver),
        ),
      );
    } on FirebaseConfigurationException catch (error) {
      _setActionError(error.toString());
    } on AuthenticationRequiredException catch (error) {
      _setActionError('$error Giriş yapıp tekrar dene.');
    } on FirebaseException catch (error) {
      _setActionError(error.message ?? error.code);
    } on StateError catch (error) {
      _setActionError(error.message);
    }
  }

  void _setActionError(String message) {
    if (mounted) {
      setState(() => _actionError = message);
    }
  }

  void _openMap(List<Listing> listings) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ListingMapScreen(listings: listings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(availableListingsProvider(_areaFilter));

    return Scaffold(
      appBar: AppBar(title: const Text('Yakınındaki bağışlar')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _areaController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Semt / mahalle',
                hintText: 'İsteğe bağlı',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Bölgeyi filtrele',
                  onPressed: () => _applyAreaFilter(),
                  icon: const Icon(Icons.arrow_forward),
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _applyAreaFilter(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _needsController,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Aradığın eşya (isteğe bağlı)',
                hintText: 'Örn. küçük çalışma masası',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_matchResult != null) {
                  setState(() => _matchResult = null);
                }
              },
            ),
          ),
          if (_actionError case final message?)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: listings.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Bağışlar yüklenemedi: $error'),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Bu bölgede uygun bağış ilanı bulunamadı.'),
                    ),
                  );
                }
                final scores = {
                  for (final match in _matchResult?.matches ?? <ListingMatch>[])
                    match.listingId: match,
                };
                final orderedItems = _matchResult == null
                    ? items
                    : [
                        for (final match in _matchResult!.matches)
                          for (final listing in items)
                            if (listing.id == match.listingId) listing,
                      ];
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'AI en yeni 15 uygun ilanı en fazla 20 saniye '
                            'içinde sıralar; kullanılamazsa yerel eşleşme '
                            'kullanılır.',
                          ),
                          OutlinedButton.icon(
                            onPressed: _isRanking
                                ? null
                                : () => _rankListings(items),
                            icon: const Icon(Icons.auto_awesome_outlined),
                            label: Text(
                              _isRanking
                                  ? 'İlanlar sıralanıyor...'
                                  : 'İhtiyacıma göre sırala',
                            ),
                          ),
                          if (_matchResult?.usedFallback ?? false)
                            const Text(
                              'AI kullanılamadı; yerel eşleştirme sonuçları '
                              'gösteriliyor.',
                            ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _openMap(orderedItems),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Haritada gör'),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: orderedItems.length,
                        itemBuilder: (context, index) {
                          final listing = orderedItems[index];
                          final match = scores[listing.id];
                          return Card(
                            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    listing.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(listing.description),
                                  if (match != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      '${match.score}/100 · ${match.reason}',
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    '${listing.category.label} · '
                                    '${listing.condition.label} · '
                                    '${listing.pickupArea}',
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: () => _reserve(listing),
                                      child: const Text('Ayırt ve teslim al'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _applyAreaFilter() {
    final area = _areaController.text.trim();
    setState(() {
      _areaFilter = area.isEmpty ? null : area;
      _actionError = null;
      _matchResult = null;
    });
  }
}

class ListingMapScreen extends StatelessWidget {
  const ListingMapScreen({required this.listings, super.key});

  final List<Listing> listings;

  @override
  Widget build(BuildContext context) {
    final center = listings.isEmpty
        ? PickupCoordinates(latitude: 39, longitude: 35)
        : listings.first.approximateMapCoordinates;
    return Scaffold(
      appBar: AppBar(title: const Text('Yaklaşık teslim bölgeleri')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Haritadaki pinler yaklaşık bölgeyi gösterir. Kesin adres '
              'ayırtma sonrası paylaşılır.',
            ),
          ),
          Expanded(
            child: PickupMapView(
              center: center,
              listings: listings,
              onListingSelected: (listing) {
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(listing.title),
                    content: Text(
                      '${listing.pickupArea} · ${listing.category.label}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Kapat'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
