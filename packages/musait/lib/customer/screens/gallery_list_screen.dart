import 'package:flutter/material.dart';

import 'package:musait/gallery.dart';
import 'package:musait/theme.dart';
import 'package:musait/widgets/gallery_album_view.dart';
import '../session.dart';

class CustomerGalleryScreen extends StatefulWidget {
  const CustomerGalleryScreen({super.key, required this.session});

  final CustomerSession session;

  @override
  State<CustomerGalleryScreen> createState() => _CustomerGalleryScreenState();
}

class _CustomerGalleryScreenState extends State<CustomerGalleryScreen> {
  late Future<List<GalleryAlbum>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.session.api.albums();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.session.api.albums());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Galeri')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<GalleryAlbum>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [Padding(padding: const EdgeInsets.all(24), child: Text('${snapshot.error}'))],
              );
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(
                    child: Text('Salon henüz albüm paylaşmadı.', style: TextStyle(color: muted)),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final album = items[index];
                return GalleryAlbumCard(
                  album: album,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomerAlbumScreen(session: widget.session, albumId: album.id),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class CustomerAlbumScreen extends StatelessWidget {
  const CustomerAlbumScreen({super.key, required this.session, required this.albumId});

  final CustomerSession session;
  final int albumId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GalleryAlbum>(
      future: session.api.album(albumId),
      builder: (context, snapshot) {
        final album = snapshot.data;
        return Scaffold(
          appBar: AppBar(title: Text(album?.title ?? 'Albüm')),
          body: snapshot.connectionState != ConnectionState.done
              ? const Center(child: CircularProgressIndicator())
              : snapshot.hasError
              ? Center(child: Text('${snapshot.error}'))
              : GalleryAlbumView(album: album!),
        );
      },
    );
  }
}
