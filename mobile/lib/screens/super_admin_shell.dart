import 'package:flutter/material.dart';

import '../models/models.dart';
import '../models/session.dart';
import '../theme.dart';
import 'admin_shell.dart';

class SuperAdminShell extends StatefulWidget {
  const SuperAdminShell({super.key, required this.session});

  final SessionController session;

  @override
  State<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends State<SuperAdminShell> {
  late Future<List<TenantAccount>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.session.api.fetchTenants();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.session.api.fetchTenants());
    await _future;
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreateSaasUserScreen(session: widget.session)),
    );
    if (created == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          children: [
            PanelHeader(
              title: 'İşletmeler',
              session: widget.session,
              onRefresh: _reload,
              onLogout: widget.session.logout,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reload,
                child: FutureBuilder<List<TenantAccount>>(
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
                          Center(child: Text('Henüz işletme yok', style: TextStyle(color: muted))),
                        ],
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final villa = item.type == 'villa';
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            leading: CircleAvatar(
                              backgroundColor: villa ? const Color(0xFF0D9488) : const Color(0xFFBE185D),
                              child: Icon(
                                villa ? Icons.holiday_village_outlined : Icons.content_cut,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(item.ownerEmail ?? item.typeLabel, style: const TextStyle(color: muted)),
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

class CreateSaasUserScreen extends StatefulWidget {
  const CreateSaasUserScreen({super.key, required this.session});

  final SessionController session;

  @override
  State<CreateSaasUserScreen> createState() => _CreateSaasUserScreenState();
}

class _CreateSaasUserScreenState extends State<CreateSaasUserScreen> {
  final _name = TextEditingController();
  final _ownerName = TextEditingController();
  final _ownerEmail = TextEditingController();
  final _password = TextEditingController();
  var _type = 'villa';
  var _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.session.api.createTenant(
        name: _name.text.trim(),
        type: _type,
        ownerName: _ownerName.text.trim(),
        ownerEmail: _ownerEmail.text.trim(),
        ownerPassword: _password.text,
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
    _ownerName.dispose();
    _ownerEmail.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yönetici ekle')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: _TypeCard(
                  selected: _type == 'villa',
                  label: 'Villa',
                  icon: Icons.holiday_village_outlined,
                  color: const Color(0xFF0D9488),
                  onTap: () => setState(() => _type = 'villa'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TypeCard(
                  selected: _type == 'kuafor',
                  label: 'Kuaför',
                  icon: Icons.content_cut,
                  color: const Color(0xFFBE185D),
                  onTap: () => setState(() => _type = 'kuafor'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: _type == 'kuafor' ? 'Salon adı' : 'İşletme adı'),
          ),
          const SizedBox(height: 10),
          TextField(controller: _ownerName, decoration: const InputDecoration(labelText: 'Yönetici adı')),
          const SizedBox(height: 10),
          TextField(
            controller: _ownerEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-posta'),
          ),
          const SizedBox(height: 10),
          TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Şifre')),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: _loading ? null : _submit, child: Text(_loading ? 'Ekleniyor...' : 'Oluştur')),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.selected,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? color : ink)),
            ],
          ),
        ),
      ),
    );
  }
}
