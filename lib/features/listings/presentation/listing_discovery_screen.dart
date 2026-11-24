import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../application/listing_providers.dart';
import '../../../application/user_error_message.dart';
import '../../../domain/models/listing.dart';
import '../../../domain/models/listing_match.dart';
import '../../../domain/models/pickup_coordinates.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/listing_report_repository.dart';
import '../../../firebase/firebase_providers.dart';
import '../../../firebase/firebase_runtime_config.dart';
import '../../auth/presentation/auth_screen.dart';
import '../handover/handover_screen.dart';
import 'listing_form_screen.dart';
import 'my_listings_screen.dart';
import 'my_reservations_screen.dart';
import 'listing_photo_view.dart';
import 'pickup_map_view.dart';
import '../../settings/presentation/settings_screen.dart';

class ListingDiscoveryScreen extends ConsumerStatefulWidget {
  const ListingDiscoveryScreen({super.key});

  @override
  ConsumerState<ListingDiscoveryScreen> createState() =>
      _ListingDiscoveryScreenState();
}

void _openDrawerPage(BuildContext context, Widget page) {
  Navigator.of(context).pop();
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

class _ListingDiscoveryScreenState
    extends ConsumerState<ListingDiscoveryScreen> {
  final _areaController = TextEditingController();
  final _needsController = TextEditingController();
  String? _areaFilter;
  String? _actionError;
  ListingMatchResult? _matchResult;
  bool _isRanking = false;
  final List<Listing> _additionalListings = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _paginationError;
  final Set<String> _hiddenListingIds = {};

  static const _pageSize = 30;

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
          .rankListings(
            receiverNeeds: needs,
            candidates: items.take(15).toList(growable: false),
          );
      if (mounted) {
        if (_needsController.text.trim() == needs &&
            _areaFilter == areaFilter) {
          setState(() => _matchResult = result);
        }
      }
    } on ArgumentError catch (error) {
      _setActionError(userMessageFor(error));
    } on FirebaseConfigurationException catch (error) {
      _setActionError(userMessageFor(error));
    } on FirebaseAIException catch (error) {
      _setActionError(userMessageFor(error));
    } on FirebaseAISdkException catch (error) {
      _setActionError(userMessageFor(error));
    } on FirebaseException catch (error) {
      _setActionError(userMessageFor(error));
    } finally {
      if (mounted) {
        setState(() => _isRanking = false);
      }
    }
  }

  Future<void> _reserve(Listing listing) async {
    setState(() => _actionError = null);
    try {
      final authState = ref.read(authStateProvider);
      final user = authState.value ?? await ref.read(authStateProvider.future);
      if (!mounted) {
        return;
      }
      if (user == null) {
        await Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const AuthScreen()));
        return;
      }
      if (listing.donorId == user.id) {
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Bağışı ayırt?'),
          content: const Text(
            'Ayırttığında bağışçının kesin teslim noktası seninle paylaşılır. '
            'Ayırtma 48 saat geçerlidir; bu süre içinde teslim alabilir veya '
            'ayırtmayı iptal edebilirsin.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ayırt ve devam et'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }

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
      _setActionError(userMessageFor(error));
    } on AuthenticationRequiredException {
      if (mounted) {
        await Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const AuthScreen()));
      }
    } on FirebaseException catch (error) {
      _setActionError(userMessageFor(error));
    } on StateError catch (error) {
      _setActionError(userMessageFor(error));
    }
  }

  Future<void> _reportListing(Listing listing) async {
    final authState = ref.read(authStateProvider);
    final user = authState.value ?? await ref.read(authStateProvider.future);
    if (!mounted) {
      return;
    }
    if (user == null) {
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const AuthScreen()));
      return;
    }

    final reason = await showDialog<ListingReportReason>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İlanı bildir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in ListingReportReason.values)
              ListTile(
                title: Text(option.label),
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) {
      return;
    }

    try {
      final repository = await ref.read(listingReportRepositoryProvider.future);
      await repository.reportListing(listingId: listing.id, reason: reason);
      if (mounted) {
        setState(() {
          _hiddenListingIds.add(listing.id);
          _actionError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bildirim alındı; bu ilan sana gösterilmeyecek.'),
          ),
        );
      }
    } on FirebaseConfigurationException catch (error) {
      _setActionError(userMessageFor(error));
    } on AuthenticationRequiredException catch (error) {
      _setActionError(userMessageFor(error));
    } on FirebaseException catch (error) {
      _setActionError(userMessageFor(error));
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

  Future<void> _loadMore(List<Listing> listings) async {
    if (_isLoadingMore || !_hasMore || listings.isEmpty) {
      return;
    }
    setState(() {
      _isLoadingMore = true;
      _paginationError = null;
    });
    try {
      final repository = await ref.read(listingRepositoryProvider.future);
      final page = await repository.fetchAvailablePage(
        pickupArea: _areaFilter,
        startAfterId: listings.last.id,
        limit: _pageSize,
      );
      if (mounted) {
        final knownIds = {
          ...listings.map((listing) => listing.id),
          ..._additionalListings.map((listing) => listing.id),
        };
        setState(() {
          _additionalListings.addAll(
            page.where((listing) => !knownIds.contains(listing.id)),
          );
          _hasMore = page.length == _pageSize;
        });
      }
    } on FirebaseConfigurationException catch (error) {
      if (mounted) {
        setState(() => _paginationError = userMessageFor(error));
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        setState(() => _paginationError = userMessageFor(error));
      }
    } on StateError catch (error) {
      if (mounted) {
        setState(() => _paginationError = userMessageFor(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(availableListingsProvider(_areaFilter));
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.id;
    final drawer = _buildDrawer(context);

    if (authState.hasError || !authState.hasValue || userId == null) {
      final message = authState.hasError
          ? userMessageFor(authState.error!)
          : !authState.hasValue
          ? null
          : 'Bağışları keşfetmek için hesabına giriş yap.';
      return Scaffold(
        appBar: AppBar(title: const Text('Yakınındaki bağışlar')),
        drawer: drawer,
        body: Center(
          child: authState.hasError || !authState.hasValue
              ? message == null
                    ? const CircularProgressIndicator()
                    : Text(message)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message!),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AuthScreen(),
                        ),
                      ),
                      child: const Text('Giriş yap'),
                    ),
                  ],
                ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Yakınındaki bağışlar')),
      drawer: drawer,
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
                  child: Text(userMessageFor(error)),
                ),
              ),
              data: (items) {
                final firstPageIds = items.map((listing) => listing.id).toSet();
                final pagedItems = [
                  ...items,
                  ..._additionalListings.where(
                    (listing) =>
                        !firstPageIds.contains(listing.id) &&
                        listing.status == ListingStatus.available,
                  ),
                ];
                final loadedItems = pagedItems
                    .where((listing) => !_hiddenListingIds.contains(listing.id))
                    .toList(growable: false);
                if (loadedItems.isEmpty) {
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
                final matchedItems = _matchResult == null
                    ? <Listing>[]
                    : [
                        for (final match in _matchResult!.matches)
                          for (final listing in loadedItems)
                            if (listing.id == match.listingId) listing,
                      ];
                final matchedIds = matchedItems
                    .map((listing) => listing.id)
                    .toSet();
                final orderedItems = _matchResult == null
                    ? loadedItems
                    : [
                        ...matchedItems,
                        ...loadedItems.where(
                          (listing) => !matchedIds.contains(listing.id),
                        ),
                      ];
                final showLoadMore = pagedItems.length >= _pageSize && _hasMore;
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
                                : () => _rankListings(loadedItems),
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
                        itemCount: orderedItems.length + (showLoadMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == orderedItems.length) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  if (_paginationError case final error?)
                                    Text(error),
                                  FilledButton(
                                    onPressed: _isLoadingMore
                                        ? null
                                        : () => _loadMore(pagedItems),
                                    child: Text(
                                      _isLoadingMore
                                          ? 'İlanlar yükleniyor...'
                                          : _paginationError == null
                                          ? 'Daha fazla ilan yükle'
                                          : 'Tekrar dene',
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          final listing = orderedItems[index];
                          final match = scores[listing.id];
                          return Card(
                            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListingPhotoView(listing: listing),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      if (listing.donorId == userId)
                                        const Text('Bu senin ilanındır.')
                                      else
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            FilledButton(
                                              onPressed: () =>
                                                  _reserve(listing),
                                              child: const Text(
                                                'Ayırt ve teslim al',
                                              ),
                                            ),
                                            TextButton.icon(
                                              onPressed: () =>
                                                  _reportListing(listing),
                                              icon: const Icon(
                                                Icons.flag_outlined,
                                              ),
                                              label: const Text('İlanı bildir'),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ],
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

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.volunteer_activism_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kapış',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Text('Ücretsiz eşya paylaşımı'),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Bağışları keşfet'),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Eşya bağışla'),
              onTap: () => _openDrawerPage(context, const ListingFormScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Bağışlarım'),
              onTap: () => _openDrawerPage(context, const MyListingsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_border),
              title: const Text('Ayırttıklarım'),
              onTap: () =>
                  _openDrawerPage(context, const MyReservationsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Ayarlar'),
              onTap: () => _openDrawerPage(context, const SettingsScreen()),
            ),
          ],
        ),
      ),
    );
  }

  void _applyAreaFilter() {
    final area = _areaController.text.trim();
    setState(() {
      _areaFilter = area.isEmpty ? null : area;
      _actionError = null;
      _matchResult = null;
      _additionalListings.clear();
      _hasMore = true;
      _paginationError = null;
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
              fitListings: true,
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
