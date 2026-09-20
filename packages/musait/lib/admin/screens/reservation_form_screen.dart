import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../models/session.dart';
import 'package:musait/theme.dart';

class ReservationFormScreen extends StatefulWidget {
  const ReservationFormScreen({super.key, required this.session, this.draft});

  final SessionController session;
  final ReservationDraft? draft;

  @override
  State<ReservationFormScreen> createState() => _ReservationFormScreenState();
}

class _ReservationFormScreenState extends State<ReservationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ReservationDraft _draft;
  List<ResourceItem> _resources = [];
  var _saving = false;
  var _showNotes = false;

  VerticalConfig get _vertical => widget.session.vertical!;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft ?? ReservationDraft(type: _vertical.types.keys.first);
    if (_draft.type.isEmpty) _draft.type = _vertical.types.keys.first;
    _showNotes = _draft.notes.trim().isNotEmpty;
    widget.session.api.fetchResources().then((items) {
      if (mounted) {
        setState(() {
          _resources = items;
          _draft.resourceId ??= items.isEmpty ? null : items.first.id;
        });
      }
    });
  }

  Future<void> _pickDate({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _draft.startDate : _draft.endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('tr'),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _draft.startDate = picked;
        if (_draft.endDate.isBefore(picked) || !_vertical.isRange) _draft.endDate = picked;
      } else {
        _draft.endDate = picked;
      }
    });
  }

  Future<void> _pickTime() async {
    final parts = _draft.startTime.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
    );
    if (picked == null) return;
    setState(() {
      _draft.startTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _cancelBooking() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İptal edilsin mi?'),
        content: const Text('Kayıt iptal edilir, takvimde yer açılır.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('İptal et')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.session.api.cancelReservation(_draft.id!);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_draft.id == null) {
        await widget.session.api.createReservation(_draft);
      } else {
        await widget.session.api.updateReservation(_draft);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = _draft.id != null;
    final dateFormat = DateFormat('d MMM', 'tr');

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Düzenle' : _vertical.addLabel)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TextFormField(
              initialValue: _draft.guestName,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: _vertical.customerLabel),
              validator: (value) => value == null || value.trim().isEmpty ? 'Zorunlu' : null,
              onChanged: (value) => _draft.guestName = value,
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: _draft.phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefon'),
              onChanged: (value) => _draft.phone = value,
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: _draft.email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-posta (hatırlatma)'),
              onChanged: (value) => _draft.email = value,
            ),
            if (_resources.isNotEmpty) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _draft.resourceId ?? _resources.first.id,
                decoration: InputDecoration(labelText: _vertical.resourceLabel),
                items: _resources
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(
                          item.region == null || item.region!.isEmpty ? item.name : '${item.name} · ${item.region}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _draft.resourceId = value),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: _vertical.isRange ? 'Giriş' : 'Tarih',
                    value: dateFormat.format(_draft.startDate),
                    onTap: () => _pickDate(start: true),
                  ),
                ),
                if (_vertical.isRange) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DateButton(
                      label: 'Çıkış',
                      value: dateFormat.format(_draft.endDate),
                      onTap: () => _pickDate(start: false),
                    ),
                  ),
                ],
              ],
            ),
            if (_vertical.timeEnabled) ...[
              const SizedBox(height: 8),
              _DateButton(label: 'Saat', value: _draft.startTime, onTap: _pickTime),
            ],
            if (isEdit) ...[
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'onaylandi', label: Text('Onaylı')),
                  ButtonSegment(value: 'beklemede', label: Text('Bekler')),
                  ButtonSegment(value: 'iptal', label: Text('İptal')),
                ],
                selected: {_draft.status},
                onSelectionChanged: (value) => setState(() => _draft.status = value.first),
              ),
            ],
            const SizedBox(height: 8),
            if (!_showNotes)
              TextButton(
                onPressed: () => setState(() => _showNotes = true),
                child: const Text('Not ekle'),
              )
            else
              TextFormField(
                initialValue: _draft.notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Not'),
                onChanged: (value) => _draft.notes = value,
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Kaydediliyor...' : (isEdit ? 'Kaydet' : 'Ekle')),
            ),
            if (isEdit && _draft.status != 'iptal') ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _saving ? null : _cancelBooking,
                child: const Text('İptal et'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: muted, fontSize: 12)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
