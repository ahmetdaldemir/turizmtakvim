import 'package:flutter/material.dart';

import '../models/models.dart';
import '../models/session.dart';
import '../theme.dart';
import 'admin_shell.dart';

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
    setState(() => _future = widget.session.api.fetchCustomers());
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
                              [item.email, item.phone].whereType<String>().where((value) => value.isNotEmpty).join('\n'),
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

class AddCustomerSheet extends StatefulWidget {
  const AddCustomerSheet({super.key, required this.session});

  final SessionController session;

  @override
  State<AddCustomerSheet> createState() => _AddCustomerSheetState();
}

class _AddCustomerSheetState extends State<AddCustomerSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  var _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.session.api.createCustomer(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
      );
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
    _email.dispose();
    _phone.dispose();
    _password.dispose();
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
          const Text('Müşteri ekle', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Ad')),
          const SizedBox(height: 10),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-posta')),
          const SizedBox(height: 10),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefon')),
          const SizedBox(height: 10),
          TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Şifre')),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 14),
          FilledButton(onPressed: _loading ? null : _submit, child: Text(_loading ? 'Ekleniyor...' : 'Kaydet')),
        ],
      ),
    );
  }
}
