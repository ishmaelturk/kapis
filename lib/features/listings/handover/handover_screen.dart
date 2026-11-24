import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../application/pickup_proximity_provider.dart';
import '../../../domain/models/handover_qr_payload.dart';
import '../../../domain/models/listing.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/services/pickup_proximity_service.dart';
import '../../../firebase/firebase_providers.dart';
import '../../../firebase/firebase_runtime_config.dart';
import 'handover_qr_scanner_screen.dart';

enum HandoverMode { donor, receiver }

class HandoverScreen extends ConsumerStatefulWidget {
  const HandoverScreen({required this.listing, required this.mode, super.key});

  final Listing listing;
  final HandoverMode mode;

  @override
  ConsumerState<HandoverScreen> createState() => _HandoverScreenState();
}

class _HandoverScreenState extends ConsumerState<HandoverScreen> {
  HandoverQrPayload? _handoverCode;
  PickupGeofenceResult? _geofenceResult;
  String? _message;
  String? _errorMessage;
  bool _isWorking = false;
  bool _isComplete = false;

  Future<void> _issueCode() async {
    await _runAction(() async {
      final repository = await ref.read(handoverRepositoryProvider.future);
      _handoverCode = await repository.issueHandoverCode(widget.listing.id);
      _message = 'Kod oluşturuldu. QR kodunu alıcıya yüz yüze göster.';
    });
  }

  Future<void> _verifyLocation() async {
    await _runAction(() async {
      final repository = await ref.read(handoverRepositoryProvider.future);
      final pickupCoordinates = await repository.getPickupCoordinates(
        widget.listing.id,
      );
      final proximityService = ref.read(pickupProximityServiceProvider);
      final result = await proximityService.verifyAtPickup(pickupCoordinates);
      _geofenceResult = result;
      _message = result.isWithinPickupRadius
          ? 'Konum doğrulandı. Bağışçının QR kodunu tarayabilirsin.'
          : '100 metre içinde ve yeterli doğrulukta konum doğrulanamadı '
                '(uzaklık ${result.distanceMeters.toStringAsFixed(0)} m, '
                'doğruluk ±${result.accuracyMeters.toStringAsFixed(0)} m).';
      if (!result.isWithinPickupRadius) {
        _errorMessage = _message;
        _message = null;
      }
    });
  }

  Future<void> _scanAndConfirm() async {
    final rawValue = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const HandoverQrScannerScreen()),
    );
    if (rawValue == null || !mounted) {
      return;
    }
    await _runAction(() async {
      final payload = HandoverQrPayload.parse(rawValue);
      if (payload.listingId != widget.listing.id) {
        throw const FormatException('Bu QR kod başka bir bağış ilanına ait.');
      }
      final repository = await ref.read(handoverRepositoryProvider.future);
      await repository.confirmHandover(payload);
      _isComplete = true;
      _message = 'Teslim alma tamamlandı. Teşekkürler!';
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() {
      _isWorking = true;
      _errorMessage = null;
      _message = null;
    });
    try {
      await action();
    } on FirebaseConfigurationException catch (error) {
      _errorMessage = error.toString();
    } on AuthenticationRequiredException catch (error) {
      _errorMessage = '$error Giriş yapıp tekrar dene.';
    } on PickupLocationAccessException catch (error) {
      _errorMessage = error.message;
    } on FirebaseException catch (error) {
      _errorMessage = error.message ?? error.code;
    } on PlatformException catch (error) {
      _errorMessage = error.message ?? error.code;
    } on TimeoutException {
      _errorMessage = 'Konum alınamadı. Tekrar dene.';
    } on FormatException catch (error) {
      _errorMessage = error.message;
    } on StateError catch (error) {
      _errorMessage = error.message;
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDonor = widget.mode == HandoverMode.donor;
    return Scaffold(
      appBar: AppBar(title: Text(widget.listing.title)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            widget.listing.pickupArea,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text('Teslimat yoktur; eşya yalnızca bağışçıdan elden alınır.'),
          if (isDonor && widget.listing.status != ListingStatus.reserved) ...[
            const SizedBox(height: 24),
            const Text(
              'Alıcı ayırttığında bu ekrandan bir devir QR kodu üret.',
            ),
          ] else if (isDonor) ...[
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isWorking ? null : _issueCode,
              child: const Text('Devir QR kodu oluştur'),
            ),
            if (_handoverCode case final code?) ...[
              const SizedBox(height: 20),
              Center(
                child: QrImageView(
                  data: code.toString(),
                  version: QrVersions.auto,
                  size: 240,
                ),
              ),
              const Text(
                'Bu kodu yalnızca alıcıya yüz yüze göster. Kodda kesin adres '
                'bulunmaz.',
                textAlign: TextAlign.center,
              ),
            ],
          ] else if (!_isComplete) ...[
            const SizedBox(height: 24),
            const Text(
              'QR taraması açılmadan önce uygulama yaklaşık konum doğruluğunu '
              'da hesaba katarak 100 m sınırını kontrol eder.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isWorking ? null : _verifyLocation,
              child: const Text('Teslim noktasında olduğumu doğrula'),
            ),
            if (_geofenceResult?.isWithinPickupRadius ?? false) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isWorking ? null : _scanAndConfirm,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Bağışçının QR kodunu tara'),
              ),
            ],
          ] else ...[
            const SizedBox(height: 20),
            const Icon(Icons.check_circle_outline, size: 56),
          ],
          if (_isWorking) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_message case final message?) ...[
            const SizedBox(height: 16),
            Text(message),
          ],
          if (_errorMessage case final message?) ...[
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
