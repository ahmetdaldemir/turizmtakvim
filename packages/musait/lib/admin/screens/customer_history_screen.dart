import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../models/session.dart';
import 'package:musait/theme.dart';
import 'customer_form_sheet.dart';

final _money = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
final _day = DateFormat('d MMMM y', 'tr');

class CustomerHistoryScreen extends StatefulWidget {
  const CustomerHistoryScreen({super.key, required this.session, required this.customer});

  final SessionController session;
  final ManagedCustomer customer;

  @override
  State<CustomerHistoryScreen> createState() => _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState extends State<CustomerHistoryScreen> {
  late ManagedCustomer _customer;
  late Future<CustomerHistory> _future;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _future = widget.session.api.fetchCustomerHistory(_customer.id);
  }

  Future<void> _reload() async {
    final next = widget.session.api.fetchCustomerHistory(_customer.id);
    setState(() {
      _future = next;
    });
    final history = await next;
    if (mounted) setState(() => _customer = history.customer);
  }

  Future<void> _edit([CustomerHistoryEntry? entry]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => CustomerEntrySheet(
        session: widget.session,
        customerId: _customer.id,
        entry: entry,
      ),
    );
    if (saved == true) await _reload();
  }

  Future<void> _delete(CustomerHistoryEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kayıt silinsin mi?'),
        content: Text('“${entry.title}” silinir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.session.api.deleteCustomerEntry(customerId: _customer.id, entryId: entry.id);
      if (mounted) await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _editProfile() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddCustomerSheet(session: widget.session, customer: _customer),
    );
    if (saved == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_customer.name),
        actions: [
          IconButton(onPressed: _editProfile, icon: const Icon(Icons.edit_outlined), tooltip: 'Bilgileri düzenle'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('İşlem ekle'),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<CustomerHistory>(
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
            final history = snapshot.data!;
            final stats = history.stats;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              children: [
                InkWell(
                  onTap: _editProfile,
                  child: Text(
                    [history.customer.email, history.customer.phone]
                        .whereType<String>()
                        .where((value) => value.isNotEmpty)
                        .join(' · '),
                    style: const TextStyle(color: muted),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _StatChip(label: 'Toplam', value: _money.format(stats.totalSpent)),
                    const SizedBox(width: 8),
                    _StatChip(label: 'İşlem', value: '${stats.visitCount}'),
                    const SizedBox(width: 8),
                    _StatChip(label: 'Randevu', value: '${stats.requestCount}'),
                  ],
                ),
                if (stats.firstVisit != null || stats.lastVisit != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    [
                      if (stats.firstVisit != null) 'İlk: ${_day.format(stats.firstVisit!)}',
                      if (stats.lastVisit != null) 'Son: ${_day.format(stats.lastVisit!)}',
                    ].join('  ·  '),
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 20),
                const Text('Kronoloji', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                if (history.timeline.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        const Text(
                          'Kesim, boya, fön gibi yapılan işi ve alınan ücreti buraya yazın. Geçmiş tarih de seçilebilir.',
                          style: TextStyle(color: muted),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => _edit(),
                          icon: const Icon(Icons.add),
                          label: const Text('İşlem ve tutar ekle'),
                        ),
                      ],
                    ),
                  )
                else
                  for (final item in history.timeline) _TimelineTile(item: item, onEdit: _edit, onDelete: _delete),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.item, required this.onEdit, required this.onDelete});

  final CustomerHistoryEntry item;
  final ValueChanged<CustomerHistoryEntry> onEdit;
  final ValueChanged<CustomerHistoryEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = item.statusColor == null
        ? muted
        : Color(int.parse('FF${item.statusColor!.replaceFirst('#', '')}', radix: 16));
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [
            _day.format(item.occurredOn),
            if (item.amount != null && item.isService) _money.format(item.amount),
            if (item.statusLabel != null) item.statusLabel,
            if ((item.notes ?? '').isNotEmpty) item.notes,
          ].join(' · '),
        ),
        trailing: item.canEdit
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(onPressed: () => onEdit(item), icon: const Icon(Icons.edit_outlined)),
                  IconButton(onPressed: () => onDelete(item), icon: const Icon(Icons.delete_outline)),
                ],
              )
            : Icon(item.isService ? Icons.payments_outlined : Icons.event_available_outlined, color: statusColor),
      ),
    );
  }
}

class CustomerEntrySheet extends StatefulWidget {
  const CustomerEntrySheet({super.key, required this.session, required this.customerId, this.entry});

  final SessionController session;
  final int customerId;
  final CustomerHistoryEntry? entry;

  @override
  State<CustomerEntrySheet> createState() => _CustomerEntrySheetState();
}

class _CustomerEntrySheetState extends State<CustomerEntrySheet> {
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _notes;
  late DateTime _day;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _title = TextEditingController(text: entry?.title ?? '');
    _amount = TextEditingController(text: entry?.amount == null || entry!.amount == 0 ? '' : entry.amount!.toStringAsFixed(0));
    _notes = TextEditingController(text: entry?.notes ?? '');
    _day = entry?.occurredOn ?? DateTime.now();
  }

  Future<void> _pickDay() async {
    final next = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2018),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (next != null) setState(() => _day = next);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'İşlem adı yazın.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final amount = asMoney(_amount.text.trim().isEmpty ? 0 : _amount.text.trim());
      if (widget.entry == null) {
        await widget.session.api.createCustomerEntry(
          customerId: widget.customerId,
          title: _title.text.trim(),
          occurredOn: _day,
          amount: amount,
          notes: _notes.text.trim(),
        );
      } else {
        await widget.session.api.updateCustomerEntry(
          customerId: widget.customerId,
          entryId: widget.entry!.id,
          title: _title.text.trim(),
          occurredOn: _day,
          amount: amount,
          notes: _notes.text.trim(),
        );
      }
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
    _amount.dispose();
    _notes.dispose();
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
          Text(widget.entry == null ? 'İşlem ekle' : 'İşlemi düzenle', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Geçmiş tarihli hizmet ve alınan tutarı kaydedin.', style: TextStyle(color: muted)),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Yapılan işlem'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Alınan tutar (₺)'),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tarih'),
            subtitle: Text(_day.year == DateTime.now().year && _day.month == DateTime.now().month && _day.day == DateTime.now().day
                ? 'Bugün'
                : DateFormat('d MMMM y', 'tr').format(_day)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDay,
          ),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Not (isteğe bağlı)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 14),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Kaydediliyor...' : 'Kaydet')),
        ],
      ),
    );
  }
}
