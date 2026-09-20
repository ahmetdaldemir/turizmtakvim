import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../models/session.dart';
import 'package:musait/theme.dart';
import 'admin_shell.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key, required this.session, this.onChanged});

  final SessionController session;
  final VoidCallback? onChanged;

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  late Future<List<BookingRequest>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.session.api.fetchRequests();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.session.api.fetchRequests());
    await _future;
    widget.onChanged?.call();
  }

  Future<void> _approve(BookingRequest item) async {
    try {
      await widget.session.api.approveRequest(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Onaylandı')));
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _reject(BookingRequest item) async {
    try {
      await widget.session.api.rejectRequest(item.id, 'Uygun değil');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reddedildi')));
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PanelHeader(
              title: 'Talepler',
              session: widget.session,
              onRefresh: _reload,
              onLogout: widget.session.logout,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reload,
                child: FutureBuilder<List<BookingRequest>>(
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
                    final pending = items.where((item) => item.isPending).toList();
                    if (pending.isEmpty) {
                      return ListView(
                        children: const [
                          SizedBox(height: 80),
                          Center(child: Text('Bekleyen talep yok', style: TextStyle(color: muted))),
                        ],
                      );
                    }
                    final format = DateFormat('d MMM', 'tr');
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: pending.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = pending[index];
                        final when = item.startTime == null
                            ? '${format.format(item.startDate)} – ${format.format(item.endDate)}'
                            : '${format.format(item.startDate)}  ${item.startTime}';
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.guestName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                                const SizedBox(height: 4),
                                Text(
                                  [when, item.resourceName].whereType<String>().join(' · '),
                                  style: const TextStyle(color: muted),
                                ),
                                if ((item.notes ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(item.notes!),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: () => _approve(item),
                                        child: const Text('Onayla'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _reject(item),
                                        child: const Text('Reddet'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
