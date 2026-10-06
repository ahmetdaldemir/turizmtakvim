import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../models/session.dart';
import 'package:musait/theme.dart';
import 'admin_shell.dart';
import 'customer_form_sheet.dart';
import 'customer_history_screen.dart';

final _money = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, required this.session});

  final SessionController session;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late Future<List<ManagedCustomer>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.session.api.fetchCustomers();
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.session.api.fetchCustomers();
    });
    await _future;
  }

  Future<void> _openCreate() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddCustomerSheet(session: widget.session),
    );
    if (created == true) await _reload();
  }

  Future<void> _delete(ManagedCustomer item) async {
    try {
      await widget.session.api.deleteCustomer(item.id);
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
        onPressed: _openCreate,
        child: const Icon(Icons.person_add_alt_1),
      ),
      body: SafeArea(
        child: Column(
          children: [
            PanelHeader(
              title: 'Müşteriler',
              session: widget.session,
              onRefresh: _reload,
              onLogout: widget.session.logout,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reload,
                child: FutureBuilder<List<ManagedCustomer>>(
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
                          Center(child: Text('Henüz müşteri yok', style: TextStyle(color: muted))),
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
                            contentPadding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              [
                                if (item.visitCount > 0) '${item.visitCount} işlem · ${_money.format(item.totalSpent)}',
                                item.email,
                                item.phone,
                              ].whereType<String>().where((value) => value.isNotEmpty).join('\n'),
                            ),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CustomerHistoryScreen(session: widget.session, customer: item),
                                ),
                              );
                              await _reload();
                            },
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () async {
                                    final saved = await showModalBottomSheet<bool>(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (context) => AddCustomerSheet(session: widget.session, customer: item),
                                    );
                                    if (saved == true) await _reload();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _delete(item),
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
