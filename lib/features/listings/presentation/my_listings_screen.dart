import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../application/listing_providers.dart';
import '../../../application/user_error_message.dart';
import '../../../domain/models/listing.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../firebase/firebase_providers.dart';
import '../../../firebase/firebase_runtime_config.dart';
import '../handover/handover_screen.dart';
import 'listing_form_screen.dart';
import 'listing_photo_view.dart';

class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});

  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

enum _ListingAction { edit, withdraw }

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  Future<void> _edit(Listing listing) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ListingFormScreen(listing: listing),
      ),
    );
  }

  Future<void> _withdraw(Listing listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İlanı geri çek?'),
        content: const Text(
          'İlan keşif listesinden kaldırılacak. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('İlanı geri çek'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    try {
      final repository = await ref.read(listingRepositoryProvider.future);
      await repository.withdraw(listing.id);
    } on FirebaseConfigurationException {
      _showMessage('Firebase ayarları tamamlanmamış.');
    } on AuthenticationRequiredException {
      _showMessage('Bu işlem için hesabına giriş yap.');
    } on FirebaseException {
      _showMessage(
        'İlan geri çekilemedi. Bağlantını kontrol edip tekrar dene.',
      );
    } on StateError {
      _showMessage('Bu ilan artık geri çekilemiyor.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final listings = ref.watch(myListingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bağışlarım')),
      body: listings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(userMessageFor(error)),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Henüz bir bağış ilanı yok.'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final listing = items[index];
              return Card(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Column(
                  children: [
                    ListingPhotoView(listing: listing, height: 140),
                    ListTile(
                      title: Text(listing.title),
                      subtitle: Text(
                        '${listing.pickupArea} · ${_statusLabel(listing.status)}',
                      ),
                      trailing: listing.status == ListingStatus.reserved
                          ? IconButton(
                              tooltip: 'Devir QR kodu',
                              icon: const Icon(Icons.qr_code_2),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => HandoverScreen(
                                    listing: listing,
                                    mode: HandoverMode.donor,
                                  ),
                                ),
                              ),
                            )
                          : listing.status == ListingStatus.available
                          ? PopupMenuButton<_ListingAction>(
                              tooltip: 'İlan işlemleri',
                              onSelected: (action) {
                                switch (action) {
                                  case _ListingAction.edit:
                                    _edit(listing);
                                  case _ListingAction.withdraw:
                                    _withdraw(listing);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: _ListingAction.edit,
                                  child: Text('Düzenle'),
                                ),
                                PopupMenuItem(
                                  value: _ListingAction.withdraw,
                                  child: Text('Yayından kaldır'),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _statusLabel(ListingStatus status) {
    return switch (status) {
      ListingStatus.available => 'Alıcı bekleniyor',
      ListingStatus.reserved => 'Ayırtıldı',
      ListingStatus.handedOver => 'Teslim edildi',
      ListingStatus.withdrawn => 'Yayından kaldırıldı',
    };
  }
}
