import 'package:flutter/material.dart';

import '../models/models.dart';
import '../models/session.dart';
import 'package:musait/theme.dart';
import 'admin_shell.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key, required this.session});

  final SessionController session;

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  late Future<List<ResourceItem>> _future;

  VerticalConfig get _vertical => widget.session.vertical!;

  @override
  void initState() {
    super.initState();
    _future = widget.session.api.fetchResources();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.session.api.fetchResources());
    await _future;
  }

  Future<void> _openForm([ResourceItem? item]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ResourceSheet(session: widget.session, item: item),
    );
    if (saved == true) await _reload();
  }

  Future<void> _delete(ResourceItem item) async {
    try {
      await widget.session.api.deleteResource(item.id);
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          children: [
            PanelHeader(
              title: _vertical.resourcePlural,
              session: widget.session,
              onRefresh: _reload,
              onLogout: widget.session.logout,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reload,
                child: FutureBuilder<List<ResourceItem>>(
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
                        children: [
                          const SizedBox(height: 80),
                          Center(
                            child: Text(
                              'Henüz ${_vertical.resourceLabel.toLowerCase()} yok',
                              style: const TextStyle(color: muted),
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Card(
                          child: ListTile(
                            onTap: () => _openForm(item),
                            contentPadding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                            leading: CircleAvatar(
                              backgroundColor: colorFromHex(item.color),
                              child: Text(
                                item.name.isEmpty ? '?' : item.name[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              item.subtitle.isEmpty ? 'Bölge yok' : item.subtitle,
                              style: const TextStyle(color: muted),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(item),
                            ),
                          ),
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

class ResourceSheet extends StatefulWidget {
  const ResourceSheet({super.key, required this.session, this.item});

  final SessionController session;
  final ResourceItem? item;

  @override
  State<ResourceSheet> createState() => _ResourceSheetState();
}

class _ResourceSheetState extends State<ResourceSheet> {
  late final TextEditingController _name;
  late final TextEditingController _region;
  late final TextEditingController _description;
  var _loading = false;
  String? _error;

  VerticalConfig get _vertical => widget.session.vertical!;
  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item?.name ?? '');
    _region = TextEditingController(text: widget.item?.region ?? '');
    _description = TextEditingController(text: widget.item?.description ?? '');
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_editing) {
        await widget.session.api.updateResource(
          id: widget.item!.id,
          name: _name.text.trim(),
          region: _region.text.trim(),
          description: _description.text.trim(),
        );
      } else {
        await widget.session.api.createResource(
          name: _name.text.trim(),
          region: _region.text.trim(),
          description: _description.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _region.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _editing ? '${_vertical.resourceLabel} düzenle' : '${_vertical.resourceLabel} ekle',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: '${_vertical.resourceLabel} adı'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _region,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Bölge'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _description,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Açıklama (isteğe bağlı)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: Text(_loading ? 'Kaydediliyor...' : 'Kaydet'),
          ),
        ],
      ),
    );
  }
}
