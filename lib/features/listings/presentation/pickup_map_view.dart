import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/models/listing.dart';
import '../../../domain/models/pickup_coordinates.dart';

class PickupMapView extends StatelessWidget {
  const PickupMapView({
    required this.center,
    this.selectedPickup,
    this.listings = const [],
    this.onMapTap,
    this.onListingSelected,
    super.key,
  });

  final PickupCoordinates center;
  final PickupCoordinates? selectedPickup;
  final List<Listing> listings;
  final ValueChanged<PickupCoordinates>? onMapTap;
  final ValueChanged<Listing>? onListingSelected;

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      if (selectedPickup case final point?)
        Marker(
          point: LatLng(point.latitude, point.longitude),
          width: 44,
          height: 44,
          child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
        ),
      for (final listing in listings)
        Marker(
          point: LatLng(
            listing.approximateMapCoordinates.latitude,
            listing.approximateMapCoordinates.longitude,
          ),
          width: 48,
          height: 48,
          child: IconButton(
            tooltip: listing.title,
            onPressed: onListingSelected == null
                ? null
                : () => onListingSelected!(listing),
            icon: const Icon(Icons.volunteer_activism),
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
    ];

    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(center.latitude, center.longitude),
        initialZoom: 12,
        onTap: onMapTap == null
            ? null
            : (_, point) => onMapTap!(
                PickupCoordinates(
                  latitude: point.latitude,
                  longitude: point.longitude,
                ),
              ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.kapis.app.kapis',
        ),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }
}
