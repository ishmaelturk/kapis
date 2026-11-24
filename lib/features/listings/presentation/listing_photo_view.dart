import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/models/listing.dart';
import '../../../firebase/firebase_providers.dart';

class ListingPhotoView extends ConsumerWidget {
  const ListingPhotoView({required this.listing, this.height = 180, super.key});

  final Listing listing;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (listing.imagePaths.isEmpty) {
      return const SizedBox.shrink();
    }

    return ref
        .watch(listingImageUrlProvider(listing.imagePaths.first))
        .when(
          loading: () => SizedBox(
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => SizedBox(
            height: height,
            child: const Center(child: Text('Fotoğraf yüklenemedi.')),
          ),
          data: (url) => Image.network(
            url,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => SizedBox(
              height: height,
              child: const Center(child: Text('Fotoğraf yüklenemedi.')),
            ),
          ),
        );
  }
}
