import 'package:flutter/material.dart';

import '../gallery.dart';
import '../theme.dart';

class GalleryAlbumView extends StatelessWidget {
  const GalleryAlbumView({super.key, required this.album});

  final GalleryAlbum album;

  @override
  Widget build(BuildContext context) {
    final photos = album.photos;
    if (photos.isEmpty) {
      return const Center(child: Text('Bu albümde görsel yok.', style: TextStyle(color: muted)));
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GalleryPhotoPager(photos: photos, initialIndex: index, title: album.title),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(photo.url, fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}

class GalleryPhotoPager extends StatefulWidget {
  const GalleryPhotoPager({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.title,
  });

  final List<GalleryPhoto> photos;
  final int initialIndex;
  final String title;

  @override
  State<GalleryPhotoPager> createState() => _GalleryPhotoPagerState();
}

class _GalleryPhotoPagerState extends State<GalleryPhotoPager> {
  late final PageController _controller;
  late var _index = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${widget.title} · ${_index + 1}/${widget.photos.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            child: Center(
              child: Image.network(widget.photos[index].url, fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}

class GalleryAlbumCard extends StatelessWidget {
  const GalleryAlbumCard({super.key, required this.album, required this.onTap});

  final GalleryAlbum album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: album.coverUrl == null
                  ? const ColoredBox(color: Color(0xFFE5E7EB), child: Icon(Icons.photo_library_outlined, color: muted))
                  : Image.network(album.coverUrl!, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(album.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('${album.photoCount} görsel', style: const TextStyle(color: muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
