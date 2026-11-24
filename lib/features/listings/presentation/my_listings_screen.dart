import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../application/listing_providers.dart';
import '../../../domain/models/listing.dart';
import '../handover/handover_screen.dart';

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(myListingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bağışlarım')),
      body: listings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Bağışların yüklenemedi: $error'),
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
                child: ListTile(
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
                      : null,
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
