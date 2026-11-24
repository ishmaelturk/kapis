import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../application/listing_providers.dart';
import '../../../domain/models/listing.dart';
import '../../../firebase/firebase_providers.dart';
import '../../auth/presentation/auth_screen.dart';
import '../handover/handover_screen.dart';

class MyReservationsScreen extends ConsumerWidget {
  const MyReservationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    if (authState.hasValue && authState.value == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ayırttıklarım')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ayırttığın bağışları görmek için giriş yap.'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
                ),
                child: const Text('Giriş yap'),
              ),
            ],
          ),
        ),
      );
    }

    final reservations = ref.watch(myReservationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ayırttıklarım')),
      body: reservations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Ayırttığın bağışlar yüklenemedi.'),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text('Şu anda ayırttığın bir bağış bulunmuyor.'),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final listing = items[index];
              return _ReservationTile(listing: listing);
            },
          );
        },
      ),
    );
  }
}

class _ReservationTile extends StatelessWidget {
  const _ReservationTile({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: ListTile(
        title: Text(listing.title),
        subtitle: Text('${listing.pickupArea} · Ayırtıldı'),
        trailing: IconButton(
          tooltip: 'Teslimata devam et',
          icon: const Icon(Icons.arrow_forward),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  HandoverScreen(listing: listing, mode: HandoverMode.receiver),
            ),
          ),
        ),
      ),
    );
  }
}
