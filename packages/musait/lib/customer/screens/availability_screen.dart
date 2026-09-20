import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models.dart';
import '../session.dart';
import 'package:musait/theme.dart';

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key, required this.session, required this.business});

  final CustomerSession session;
  final Business business;

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  DateTime? _end;
  VerticalConfig? _vertical;
  List<ResourceItem> _resources = [];
  Set<String> _occupied = {};
  List<String> _slots = [];
  int? _resourceId;
  String? _type;
  String? _time;
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _busy(DateTime day) => _occupied.contains(isoDate(day));

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.session.api.availability(
        businessId: widget.business.id,
        year: _focused.year,
        month: _focused.month,
        resourceId: _resourceId,
      );
      final verticalJson = data['vertical'] as Map<String, dynamic>;
      final resources = (data['resources'] as List)
          .map((item) => ResourceItem.fromJson(item as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _vertical = VerticalConfig.fromJson(verticalJson, data['slots'] as List? ?? []);
        _resources = resources;
        _occupied = ((data['occupiedDates'] as List?) ?? []).map((item) => item.toString()).toSet();
        _slots = _vertical!.slots;
        _type ??= _vertical!.types.keys.first;
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

  Future<void> _submit() async {
    try {
      await widget.session.api.createRequest({
        'tenantId': widget.business.id,
        'resourceId': _resourceId,
        'startDate': isoDate(_selected),
        'endDate': isoDate(_end ?? _selected),
        'startTime': _time,
        'type': _type,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Talebiniz yöneticiye iletildi.')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.business.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_resources.isNotEmpty)
                  DropdownButtonFormField<int>(
                    initialValue: _resourceId,
                    decoration: InputDecoration(labelText: _vertical!.resourceLabel),
                    items: _resources
                        .map((item) => DropdownMenuItem(value: item.id, child: Text(item.label)))
                        .toList(),
                    onChanged: (value) {
                      _resourceId = value;
                      _load();
                    },
                  ),
                const SizedBox(height: 12),
                Card(
                  child: TableCalendar(
                    locale: 'tr_TR',
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2035, 12, 31),
                    focusedDay: _focused,
                    selectedDayPredicate: (day) => isSameDay(_selected, day),
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    calendarStyle: CalendarStyle(
                      selectedDecoration: const BoxDecoration(color: teal, shape: BoxShape.circle),
                      todayDecoration: BoxDecoration(
                        color: teal.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      outsideDaysVisible: false,
                    ),
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focused) {
                        if (_busy(day)) {
                          return Center(
                            child: Text(
                              '${day.day}',
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          );
                        }
                        return null;
                      },
                    ),
                    onDaySelected: (selected, focused) {
                      if (_busy(selected)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bu gün rezerve. Müsait bir gün seçin.')),
                        );
                        return;
                      }
                      setState(() {
                        _selected = selected;
                        _focused = focused;
                        _time = null;
                        if (_vertical?.dateMode == 'range' && _end != null && _end!.isBefore(selected)) {
                          _end = selected;
                        }
                      });
                    },
                    onPageChanged: (focused) {
                      _focused = focused;
                      _load();
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Kırmızı / üstü çizili günler dolu. Müsait güne talep oluşturun.'),
                if (_vertical?.dateMode == 'range') ...[
                  const SizedBox(height: 8),
                  ListTile(
                    title: const Text('Çıkış tarihi'),
                    subtitle: Text(isoDate(_end ?? _selected)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _end ?? _selected,
                        firstDate: _selected,
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setState(() => _end = picked);
                    },
                  ),
                ],
                if (_vertical?.timeEnabled == true) ...[
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
                if (_vertical!.types.length > 1) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _vertical!.types.entries.map((entry) {
                      return ChoiceChip(
                        label: Text(entry.value),
                        selected: _type == entry.key,
                        onSelected: (_) => setState(() => _type = entry.key),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: (_vertical!.timeEnabled && _time == null) ? null : _submit,
                  child: const Text('Randevu talebi gönder'),
                ),
              ],
            ),
    );
  }
}
