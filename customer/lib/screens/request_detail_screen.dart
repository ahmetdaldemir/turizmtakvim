import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../session.dart';
import '../theme.dart';

class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key, required this.session, required this.item});

  final CustomerSession session;
  final BookingRequest item;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  late BookingRequest _item;
  late DateTime _start;
  late DateTime _end;
  String? _time;
  int? _resourceId;
  List<ResourceItem> _resources = [];
  List<String> _slots = [];
  var _timeEnabled = false;
  var _range = false;
  var _loading = true;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _start = _item.startDate;
    _end = _item.endDate;
    _time = _item.startTime;
    _resourceId = _item.resourceId;
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    try {
      final data = await widget.session.api.availability(
        businessId: _item.tenantId,
        year: _start.year,
        month: _start.month,
        resourceId: _resourceId,
      );
      final vertical = VerticalConfig.fromJson(
        data['vertical'] as Map<String, dynamic>,
        data['slots'] as List? ?? [],
      );
      final resources = (data['resources'] as List)
          .map((item) => ResourceItem.fromJson(item as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _resources = resources;
        _slots = vertical.slots;
        _timeEnabled = vertical.timeEnabled;
        _range = vertical.dateMode == 'range';
        _resourceId ??= resources.isEmpty ? null : resources.first.id;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
      locale: const Locale('tr'),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_end.isBefore(picked) || !_range) _end = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await widget.session.api.updateRequest(_item.id, {
        'startDate': isoDate(_start),
        'endDate': isoDate(_end),
        'startTime': _time,
        'resourceId': _resourceId,
      });
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İptal edilsin mi?'),
        content: const Text('Randevu / rezervasyon iptal edilecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('İptal et')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final updated = await widget.session.api.cancelRequest(_item.id);
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('d MMMM yyyy', 'tr');
    return Scaffold(
      appBar: AppBar(title: const Text('Randevu / rezervasyon')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(_item.tenantName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
                const SizedBox(height: 6),
                Text(_item.statusLabel, style: TextStyle(color: Color(int.parse('FF${_item.statusColor.replaceFirst('#', '')}', radix: 16)), fontWeight: FontWeight.w700)),
                if ((_item.resourceName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(_item.resourceName!, style: const TextStyle(color: Color(0xFF6B7280))),
                ],
                const SizedBox(height: 20),
                if (_item.canEdit) ...[
                  if (_resources.isNotEmpty)
                    DropdownButtonFormField<int>(
                      initialValue: _resourceId,
                      decoration: const InputDecoration(labelText: 'Seçim'),
                      items: _resources
                          .map((item) => DropdownMenuItem(value: item.id, child: Text(item.label)))
                          .toList(),
                      onChanged: (value) => setState(() => _resourceId = value),
                    ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_range ? 'Giriş' : 'Tarih'),
                    subtitle: Text(format.format(_start)),
                    trailing: const Icon(Icons.event),
                    onTap: () => _pickDate(start: true),
                  ),
                  if (_range)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Çıkış'),
                      subtitle: Text(format.format(_end)),
                      trailing: const Icon(Icons.event),
                      onTap: () => _pickDate(start: false),
                    ),
                  if (_timeEnabled) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _slots.map((slot) {
                        return ChoiceChip(
                          label: Text(slot),
                          selected: _time == slot,
                          onSelected: (_) => setState(() => _time = slot),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Kaydediliyor...' : 'Değişiklikleri kaydet'),
                  ),
                ] else ...[
                  Text(
                    _item.startTime == null
                        ? '${format.format(_item.startDate)} – ${format.format(_item.endDate)}'
                        : '${format.format(_item.startDate)}  ${_item.startTime}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  if ((_item.notes ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_item.notes!),
                  ],
                ],
                if (_item.canCancel) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _saving ? null : _cancel,
                    child: const Text('İptal et'),
                  ),
                ],
              ],
            ),
    );
  }
}
