import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../session.dart';
import 'request_detail_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key, required this.session});
  final CustomerSession session;

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  late Future<List<BookingRequest>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.session.api.myRequests();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.session.api.myRequests());
    await _future;
  }

  Future<void> _open(BookingRequest item) async {
    final changed = await Navigator.push<BookingRequest>(
      context,
      MaterialPageRoute(
        builder: (_) => RequestDetailScreen(session: widget.session, item: item),
      ),
    );
    if (changed != null) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Randevu / rezervasyon')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<BookingRequest>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('${snapshot.error}'))]);
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return ListView(children: const [SizedBox(height: 80), Center(child: Text('Henüz kaydınız yok.'))]);
            }
            final format = DateFormat('d MMM', 'tr');
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                final when = item.startTime == null
                    ? '${format.format(item.startDate)} – ${format.format(item.endDate)}'
                    : '${format.format(item.startDate)} ${item.startTime}';
                return Card(
                  child: ListTile(
                    title: Text(item.tenantName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([when, item.resourceName, item.typeLabel].whereType<String>().where((v) => v.isNotEmpty).join(' · ')),
                    trailing: Text(
                      item.statusLabel,
                      style: TextStyle(
                        color: Color(int.parse('FF${item.statusColor.replaceFirst('#', '')}', radix: 16)),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () => _open(item),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
