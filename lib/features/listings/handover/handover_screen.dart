import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../application/pickup_proximity_provider.dart';
import '../../../application/user_error_message.dart';
import '../../../domain/models/handover_qr_payload.dart';
import '../../../domain/models/listing.dart';
import '../../../domain/models/pickup_coordinates.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/services/pickup_proximity_service.dart';
import '../../../firebase/firebase_providers.dart';
import '../../../firebase/firebase_runtime_config.dart';
import 'handover_qr_scanner_screen.dart';
import '../presentation/pickup_map_view.dart';

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
  PickupCoordinates? _pickupCoordinates;
  String? _message;
  String? _errorMessage;
  bool _isWorking = false;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    if (widget.mode == HandoverMode.receiver) {
      unawaited(_loadPickupCoordinates());
    }
  }

  Future<void> _loadPickupCoordinates() async {
    await _runAction(() async {
      final repository = await ref.read(handoverRepositoryProvider.future);
      _pickupCoordinates = await repository.getPickupCoordinates(
        widget.listing.id,
      );
    });
  }

  Future<void> _issueCode() async {
    await _runAction(() async {
      final repository = await ref.read(handoverRepositoryProvider.future);
      _handoverCode = await repository.issueHandoverCode(widget.listing.id);
      _message = 'Kod oluşturuldu. QR kodunu alıcıya yüz yüze göster.';
    });
  }

  Future<void> _changeReservation({required bool withdraw}) async {
    final isDonor = widget.mode == HandoverMode.donor;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isDonor
              ? withdraw
                    ? 'İlanı geri çek?'
                    : 'Ayırtmayı kaldır?'
              : 'Ayırtmayı iptal et?',
        ),
        content: Text(
          isDonor
              ? withdraw
                    ? 'İlan yayından kaldırılacak ve alıcının ayırtması sona erecek.'
                    : 'Alıcının ayırtması sona erecek; ilan yeniden ayırtılabilir olacak.'
              : 'Ayırtman sona erecek ve ilan başka alıcılar için yeniden açılacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isDonor
                  ? withdraw
                        ? 'İlanı geri çek'
                        : 'Ayırtmayı kaldır'
                  : 'Ayırtmayı iptal et',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await _runAction(() async {
      final repository = await ref.read(handoverRepositoryProvider.future);
      if (isDonor) {
        await repository.releaseReservation(
          widget.listing.id,
          withdraw: withdraw,
        );
      } else {
        await repository.cancelReservation(widget.listing.id);
      }
    });
    if (mounted && _errorMessage == null) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _verifyLocation() async {
    await _runAction(() async {
      final pickupCoordinates =
          _pickupCoordinates ??
          await (await ref.read(handoverRepositoryProvider.future))
              .getPickupCoordinates(widget.listing.id);
      _pickupCoordinates = pickupCoordinates;
      final proximityService = ref.read(pickupProximityServiceProvider);
      final result = await proximityService.verifyAtPickup(pickupCoordinates);
      _geofenceResult = result;
      final accuracyOnlyFailure =
          result.distanceMeters <= PickupGeofenceResult.radiusMeters &&
          !result.isWithinPickupRadius;
      _message = result.isWithinPickupRadius
          ? 'Konum doğrulandı. Bağışçının QR kodunu tarayabilirsin.'
          : accuracyOnlyFailure
          ? 'Konum doğruluğu yeterli değil. Açık alana çık ve tekrar dene '
                '(doğruluk ±${result.accuracyMeters.toStringAsFixed(0)} m).'
          : 'Teslim noktasına 100 metre sınırında değilsin '
                '(uzaklık ${result.distanceMeters.toStringAsFixed(0)} m).';
      if (!result.isWithinPickupRadius) {
        _errorMessage = _message;
        _message = null;
      }
    });
  }

  Future<void> _openDirections() async {
    await _runAction(() async {
      final pickupCoordinates =
          _pickupCoordinates ??
          (throw StateError('Kesin teslim noktası henüz yüklenmedi.'));
      final latitude = pickupCoordinates.latitude;
      final longitude = pickupCoordinates.longitude;
      final directionsUri = defaultTargetPlatform == TargetPlatform.android
          ? Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude')
          : Uri.https('maps.apple.com', '/', {'daddr': '$latitude,$longitude'});
      if (!await launchUrl(
        directionsUri,
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('Harita uygulaması açılamadı.');
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
      _errorMessage = userMessageFor(error);
    } on AuthenticationRequiredException catch (error) {
      _errorMessage = userMessageFor(error);
    } on PickupLocationAccessException catch (error) {
      _errorMessage = userMessageFor(error);
    } on FirebaseException catch (error) {
      _errorMessage = userMessageFor(error);
    } on PlatformException catch (error) {
      _errorMessage = userMessageFor(error);
    } on TimeoutException {
      _errorMessage = 'Konum alınamadı. Tekrar dene.';
    } on FormatException catch (error) {
      _errorMessage = userMessageFor(error);
    } on StateError catch (error) {
      _errorMessage = userMessageFor(error);
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDonor = widget.mode == HandoverMode.donor;
    final watchedStatus = isDonor
        ? ref.watch(handoverListingStatusProvider(widget.listing.id))
        : null;
    final currentStatus = watchedStatus?.value ?? widget.listing.status;
    final isComplete = _isComplete || currentStatus == ListingStatus.handedOver;
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
          if (isDonor && (watchedStatus?.hasError ?? false)) ...[
            const SizedBox(height: 8),
            const Text(
              'Teslimat durumu güncellenemedi. Bağlantını kontrol edip tekrar dene.',
            ),
          ],
          if (isComplete) ...[
            const SizedBox(height: 20),
            const Icon(Icons.check_circle_outline, size: 56),
            const SizedBox(height: 8),
            const Text(
              'Teslim edildi. Bağış tamamlandı.',
              textAlign: TextAlign.center,
            ),
          ] else if (isDonor && currentStatus != ListingStatus.reserved) ...[
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
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _isWorking
                  ? null
                  : () => _changeReservation(withdraw: false),
              child: const Text('Ayırtmayı kaldır'),
            ),
            TextButton(
              onPressed: _isWorking
                  ? null
                  : () => _changeReservation(withdraw: true),
              child: const Text('İlanı geri çek'),
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
          ] else if (!isDonor) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isWorking
                  ? null
                  : () => _changeReservation(withdraw: false),
              child: const Text('Ayırtmayı iptal et'),
            ),
            if (_pickupCoordinates case final coordinates?) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 240,
                child: PickupMapView(
                  center: coordinates,
                  selectedPickup: coordinates,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isWorking ? null : _openDirections,
                icon: const Icon(Icons.directions),
                label: const Text('Yol tarifi'),
              ),
            ],
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
