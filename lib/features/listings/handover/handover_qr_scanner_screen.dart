import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class HandoverQrScannerScreen extends StatefulWidget {
  const HandoverQrScannerScreen({super.key});

  @override
  State<HandoverQrScannerScreen> createState() =>
      _HandoverQrScannerScreenState();
}

class _HandoverQrScannerScreenState extends State<HandoverQrScannerScreen> {
  bool _hasScanned = false;

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) {
      return;
    }
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null) {
        _hasScanned = true;
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bağış QR kodunu tara'),
        actions: [
          IconButton(
            tooltip: 'Kapat',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Bağışçının ekranda gösterdiği QR kodu çerçeveye al.'),
          ),
          Expanded(child: MobileScanner(onDetect: _onDetect)),
        ],
      ),
    );
  }
}
