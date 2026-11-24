import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../application/listing_providers.dart';
import '../../../domain/models/listing.dart';
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
  String? _areaFilter;
  String? _actionError;

  @override
  void dispose() {
    _areaController.dispose();
    super.dispose();
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
                return Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _openMap(items),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Haritada gör'),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final listing = items[index];
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
