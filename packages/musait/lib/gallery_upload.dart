import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class _Kind {
  const _Kind(this.subtype, this.ext);
  final String subtype;
  final String ext;
}

_Kind? sniffImage(Uint8List bytes) {
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return const _Kind('jpeg', 'jpg');
  }
  if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
    return const _Kind('png', 'png');
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return const _Kind('webp', 'webp');
  }
  return null;
}

Future<http.MultipartFile> galleryPhotoPart(String path) async {
  final original = await File(path).readAsBytes();
  final kind = sniffImage(original);
  if (kind != null) {
    return http.MultipartFile.fromBytes(
      'photos',
      original,
      filename: 'photo.${kind.ext}',
      contentType: MediaType('image', kind.subtype),
    );
  }

  final converted = await _encodePng(original);
  return http.MultipartFile.fromBytes(
    'photos',
    converted,
    filename: 'photo.png',
    contentType: MediaType('image', 'png'),
  );
}

Future<Uint8List> _encodePng(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1920);
    final frame = await codec.getNextFrame();
    final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) {
      throw const FormatException('empty');
    }
    return png.buffer.asUint8List();
  } catch (_) {
    throw Exception('Görsel okunamadı. JPEG, PNG veya WebP seçin.');
  }
}
