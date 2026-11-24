import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../application/app_preferences_controller.dart';
import '../../../application/pickup_proximity_provider.dart';
import '../../../domain/models/pickup_coordinates.dart';
import '../../../domain/services/pickup_proximity_service.dart';
import 'pickup_map_view.dart';

class PickupLocationPickerScreen extends ConsumerStatefulWidget {
  const PickupLocationPickerScreen({this.initialCoordinates, super.key});

  final PickupCoordinates? initialCoordinates;

  @override
  ConsumerState<PickupLocationPickerScreen> createState() =>
      _PickupLocationPickerScreenState();
}

class _PickupLocationPickerScreenState
    extends ConsumerState<PickupLocationPickerScreen> {
  static final _turkiyeCenter = PickupCoordinates(latitude: 39, longitude: 35);

  late PickupCoordinates _mapCenter;
  double _mapZoom = 6;
  PickupCoordinates? _selectedCoordinates;
  String? _errorMessage;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _mapCenter = widget.initialCoordinates ?? _turkiyeCenter;
    _selectedCoordinates = widget.initialCoordinates;
    _mapZoom = widget.initialCoordinates == null ? 6 : 12;
    if (widget.initialCoordinates == null) {
      unawaited(_chooseInitialCenter());
    }
  }

  Future<void> _chooseInitialCenter() async {
    PickupCoordinates? cachedCoordinates;
    try {
      cachedCoordinates = (await ref.read(appPreferencesProvider.future))
          .cachedPickupCoordinates;
    } on Exception {
      _errorMessage = 'Kaydedilmiş konum yüklenemedi.';
    }

    try {
      final currentCoordinates = await ref
          .read(pickupProximityServiceProvider)
          .getCurrentCoordinates(requestPermission: false);
      if (!mounted) {
        return;
      }
      setState(() {
        if (currentCoordinates != null) {
          _mapCenter = currentCoordinates;
          _mapZoom = 12;
        } else if (cachedCoordinates != null) {
          _mapCenter = cachedCoordinates;
          _mapZoom = 12;
        }
      });
    } on PlatformException {
      if (mounted) {
        setState(() => _errorMessage = 'Cihaz konumu alınamadı.');
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _errorMessage = null;
    });
    try {
      final coordinates = await ref
          .read(pickupProximityServiceProvider)
          .getCurrentCoordinates();
      if (coordinates == null) {
        throw const PickupLocationAccessException(
          'Current location is unavailable.',
        );
      }
      await ref
          .read(appPreferencesProvider.notifier)
          .cachePickupCoordinates(coordinates);
      if (mounted) {
        setState(() {
          _mapCenter = coordinates;
          _mapZoom = 12;
          _selectedCoordinates = coordinates;
        });
      }
    } on PickupLocationAccessException {
      if (mounted) {
        setState(
          () => _errorMessage = 'Konum izni ver ve konum hizmetlerini aç.',
        );
      }
    } on PlatformException {
      if (mounted) {
        setState(() => _errorMessage = 'Cihaz konumu alınamadı.');
      }
    } on Exception {
      if (mounted) {
        setState(() => _errorMessage = 'Konum tercihi kaydedilemedi.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _selectCoordinates() async {
    final coordinates = _selectedCoordinates;
    if (coordinates == null) {
      return;
    }
    try {
      await ref
          .read(appPreferencesProvider.notifier)
          .cachePickupCoordinates(coordinates);
      if (mounted) {
        Navigator.of(context).pop(coordinates);
      }
    } on Exception {
      if (mounted) {
        setState(() => _errorMessage = 'Konum tercihi kaydedilemedi.');
      }
    }
  }

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: _isLocating ? null : _useCurrentLocation,
              icon: const Icon(Icons.my_location),
              label: Text(
                _isLocating ? 'Konum alınıyor...' : 'Konumumu kullan',
              ),
            ),
          ),
          if (_errorMessage case final message?)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: PickupMapView(
              center: _mapCenter,
              initialZoom: _mapZoom,
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
                      : _selectCoordinates,
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
