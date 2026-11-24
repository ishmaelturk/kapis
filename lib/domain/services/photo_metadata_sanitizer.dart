import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as image;

Uint8List sanitizePhoto(Uint8List bytes) {
  final decoded = image.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Fotoğraf çözümlenemedi.');
  }
  if (decoded.width * decoded.height > 20000000) {
    throw const FormatException('Fotoğrafın çözünürlüğü çok yüksek.');
  }

  final oriented = image.bakeOrientation(decoded);
  final largestDimension = math.max(oriented.width, oriented.height);
  final resized = largestDimension <= 1600
      ? oriented
      : image.copyResize(
          oriented,
          width: (oriented.width * 1600 / largestDimension).round(),
          height: (oriented.height * 1600 / largestDimension).round(),
        );
  final sanitized = Uint8List.fromList(image.encodeJpg(resized, quality: 85));
  if (sanitized.length > 4 * 1024 * 1024) {
    throw const FormatException('Fotoğraf en fazla 4 MiB olmalı.');
  }
  return sanitized;
}
