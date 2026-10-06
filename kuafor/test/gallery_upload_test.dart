import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:musait/admin/models/api_service.dart';
import 'package:musait/config.dart';
import 'package:musait/gallery_upload.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  test('HEIC dosyası JPEG/PNG olarak yüklenir', () async {
    AppConfig.boot(sector: 'kuafor', apiBase: 'http://127.0.0.1:3000');
    final heic = File('test/fixtures/salon.heic');
    expect(heic.existsSync(), isTrue);

    final part = await galleryPhotoPart(heic.path);
    expect(part.filename, anyOf('photo.png', 'photo.jpg', 'photo.webp'));
    expect(part.contentType?.mimeType, anyOf('image/png', 'image/jpeg', 'image/webp'));

    final api = ApiService();
    final login = await api.login('kuafor@takvim.app', 'Demo123!');
    api.token = login['token'] as String;
    final album = await api.createAlbum(title: 'Flutter HEIC test', photoPaths: [heic.path]);
    expect(album.photoCount, 1);
    expect(album.title, 'Flutter HEIC test');
  });
}
