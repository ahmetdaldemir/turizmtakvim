import 'package:flutter/material.dart';

import 'package:musait/config.dart';
import '../models.dart';
import '../session.dart';
import 'availability_screen.dart';

class BusinessListScreen extends StatefulWidget {
  const BusinessListScreen({super.key, required this.session});
  final CustomerSession session;

  @override
  State<BusinessListScreen> createState() => _BusinessListScreenState();
}

class _BusinessListScreenState extends State<BusinessListScreen> {
  late Future<List<Business>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Business>> _load() async {
    final own = widget.session.user?.tenant;
    if (own != null) return [own];
    return widget.session.api.businesses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppConfig.appTitle),
        actions: [IconButton(onPressed: widget.session.logout, icon: const Icon(Icons.logout))],
      ),
      body: FutureBuilder<List<Business>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Sizi ekleyen işletme bulunamadı.'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(item.typeLabel),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AvailabilityScreen(session: widget.session, business: item),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
