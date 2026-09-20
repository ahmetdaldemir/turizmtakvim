import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:musait/gallery.dart';
import 'package:musait/theme.dart';
import 'package:musait/widgets/gallery_album_view.dart';
import '../models/session.dart';
import 'admin_shell.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, required this.session});

  final SessionController session;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late Future<List<GalleryAlbum>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.session.api.fetchAlbums();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.session.api.fetchAlbums());
    await _future;
  }

  Future<void> _compose() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => GalleryComposeScreen(session: widget.session)),
    );
    if (created == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _compose,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Albüm paylaş'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            PanelHeader(
              title: 'Galeri',
              subtitle: 'Her paylaşım bir albümdür',
              session: widget.session,
              onRefresh: _reload,
              onLogout: widget.session.logout,
            ),
            Expanded(
              child: RefreshIndicator(
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
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Henüz albüm yok. Görselleri seçip tek seferde paylaşın.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: muted),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final album = items[index];
                        return GalleryAlbumCard(
                          album: album,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminAlbumScreen(session: widget.session, albumId: album.id),
                              ),
                            );
                            await _reload();
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GalleryComposeScreen extends StatefulWidget {
  const GalleryComposeScreen({super.key, required this.session});

  final SessionController session;

  @override
  State<GalleryComposeScreen> createState() => _GalleryComposeScreenState();
}

class _GalleryComposeScreenState extends State<GalleryComposeScreen> {
  final _title = TextEditingController();
  final _paths = <String>[];
  var _saving = false;
  String? _error;

  Future<void> _pick() async {
    final files = await ImagePicker().pickMultiImage(imageQuality: 75, limit: 20);
    if (files.isEmpty) return;
    setState(() {
      _paths
        ..clear()
        ..addAll(files.map((file) => file.path).take(20));
      _error = null;
    });
  }

  Future<void> _publish() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Albüm adı yazın.');
      return;
    }
    if (_paths.isEmpty) {
      setState(() => _error = 'Görselleri seçin. Hepsi tek albüm olarak paylaşılır.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.session.api.createAlbum(title: _title.text.trim(), photoPaths: _paths);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Albüm paylaş')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Text(
            'Seçtiğiniz görseller bir kez, tek albüm olarak paylaşılır. Müşteriler albümü listede görür.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Albüm adı'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _saving ? null : _pick,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(_paths.isEmpty ? 'Görselleri seç' : '${_paths.length} görsel seçildi'),
          ),
          if (_paths.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _paths.length; i++)
                  Chip(label: Text('${i + 1}'), visualDensity: VisualDensity.compact),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _publish,
            child: Text(_saving ? 'Paylaşılıyor...' : 'Albümü paylaş'),
          ),
        ],
      ),
    );
  }
}

class AdminAlbumScreen extends StatefulWidget {
  const AdminAlbumScreen({super.key, required this.session, required this.albumId});

  final SessionController session;
  final int albumId;

  @override
  State<AdminAlbumScreen> createState() => _AdminAlbumScreenState();
}

class _AdminAlbumScreenState extends State<AdminAlbumScreen> {
  late Future<GalleryAlbum> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.session.api.fetchAlbum(widget.albumId);
  }

  Future<void> _delete(GalleryAlbum album) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Albüm silinsin mi?'),
        content: Text('“${album.title}” ve içindeki görseller silinir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.session.api.deleteAlbum(album.id);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GalleryAlbum>(
      future: _future,
      builder: (context, snapshot) {
        final album = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(album?.title ?? 'Albüm'),
            actions: [
              if (album != null)
                IconButton(onPressed: () => _delete(album), icon: const Icon(Icons.delete_outline)),
            ],
          ),
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
