import 'package:material_ui/material_ui.dart';

import '../../../domain/models/pickup_coordinates.dart';
import 'pickup_map_view.dart';

class PickupLocationPickerScreen extends StatefulWidget {
  const PickupLocationPickerScreen({this.initialCoordinates, super.key});

  final PickupCoordinates? initialCoordinates;

  @override
  State<PickupLocationPickerScreen> createState() =>
      _PickupLocationPickerScreenState();
}

class _PickupLocationPickerScreenState
    extends State<PickupLocationPickerScreen> {
  late final PickupCoordinates _mapCenter =
      widget.initialCoordinates ??
      PickupCoordinates(latitude: 39, longitude: 35);
  PickupCoordinates? _selectedCoordinates;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teslim alma noktasını seç')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Haritada dokunarak pin seç. Kesin konum yalnızca bağışçı ve '
              'ayırtan alıcıyla paylaşılır.',
            ),
          ),
          Expanded(
            child: PickupMapView(
              center: _mapCenter,
              selectedPickup: _selectedCoordinates,
              onMapTap: (coordinates) {
                setState(() => _selectedCoordinates = coordinates);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selectedCoordinates == null
                      ? null
                      : () => Navigator.of(context).pop(_selectedCoordinates),
                  child: const Text('Bu noktayı kullan'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
