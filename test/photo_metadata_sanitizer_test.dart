import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:kapis/domain/services/photo_metadata_sanitizer.dart';

void main() {
  test('re-encodes photos without preserving EXIF GPS metadata', () {
    final jpeg = image.encodeJpg(image.Image(width: 2, height: 2));
    final exif = <int>[
      0x45, 0x78, 0x69, 0x66, 0, 0, // Exif header
      0x47, 0x50, 0x53, 0, // GPS marker
    ];
    final segmentLength = exif.length + 2;
    final input = Uint8List.fromList([
      ...jpeg.take(2),
      0xff,
      0xe1,
      segmentLength >> 8,
      segmentLength & 0xff,
      ...exif,
      ...jpeg.skip(2),
    ]);

    final sanitized = sanitizePhoto(input);
    final decoded = image.decodeJpg(sanitized);

    expect(decoded, isNotNull);
    expect(_contains(sanitized, [0x45, 0x78, 0x69, 0x66, 0, 0]), isFalse);
    expect(_contains(sanitized, [0x47, 0x50, 0x53]), isFalse);
  });

  test('rejects undecodable image bytes', () {
    expect(
      () => sanitizePhoto(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });
}

bool _contains(List<int> bytes, List<int> sequence) {
  for (var start = 0; start <= bytes.length - sequence.length; start++) {
    var match = true;
    for (var offset = 0; offset < sequence.length; offset++) {
      if (bytes[start + offset] != sequence[offset]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}
