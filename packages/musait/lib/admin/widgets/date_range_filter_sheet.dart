import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import 'package:musait/theme.dart';

class DateRangeFilterValue {
  const DateRangeFilterValue(this.range);

  final DateTimeRange? range;

  bool get cleared => range == null;
}

class _Preset {
  const _Preset(this.id, this.label, this.range);

  final String id;
  final String label;
  final DateTimeRange range;
}

Future<DateRangeFilterValue?> showDateRangeFilterSheet({
  required BuildContext context,
  required Color seed,
  DateTimeRange? initial,
}) {
  return showModalBottomSheet<DateRangeFilterValue>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DateRangeFilterSheet(seed: seed, initial: initial),
  );
}

class DateRangeFilterSheet extends StatefulWidget {
  const DateRangeFilterSheet({super.key, required this.seed, this.initial});

  final Color seed;
  final DateTimeRange? initial;

  @override
  State<DateRangeFilterSheet> createState() => _DateRangeFilterSheetState();
}

class _DateRangeFilterSheetState extends State<DateRangeFilterSheet> {
  late DateTime _start;
  late DateTime _end;
  String? _presetId;
  final _dateFormat = DateFormat('d MMM yyyy', 'tr');

  @override
  void initState() {
    super.initState();
    final today = dateOnly(DateTime.now());
    _start = widget.initial?.start ?? today;
    _end = widget.initial?.end ?? today;
    _presetId = _matchPreset();
  }

  List<_Preset> get _presets {
    final today = dateOnly(DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(today.year, today.month, 1);
    final monthEnd = DateTime(today.year, today.month + 1, 0);
    return [
      _Preset('today', 'Bugün', DateTimeRange(start: today, end: today)),
      _Preset('week', 'Bu hafta', DateTimeRange(start: monday, end: monday.add(const Duration(days: 6)))),
      _Preset('month', 'Bu ay', DateTimeRange(start: monthStart, end: monthEnd)),
      _Preset('next7', '7 gün', DateTimeRange(start: today, end: today.add(const Duration(days: 6)))),
      _Preset('next30', '30 gün', DateTimeRange(start: today, end: today.add(const Duration(days: 29)))),
    ];
  }

  String? _matchPreset() {
    for (final preset in _presets) {
      if (dateOnly(preset.range.start) == dateOnly(_start) && dateOnly(preset.range.end) == dateOnly(_end)) {
        return preset.id;
      }
    }
    return 'custom';
  }

  void _applyPreset(_Preset preset) {
    setState(() {
      _start = dateOnly(preset.range.start);
      _end = dateOnly(preset.range.end);
      _presetId = preset.id;
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: _start, end: _end.isBefore(_start) ? _start : _end),
      locale: const Locale('tr'),
      helpText: 'Tarih aralığı seçin',
      cancelText: 'Vazgeç',
      confirmText: 'Tamam',
      saveText: 'Seç',
      fieldStartLabelText: 'Başlangıç',
      fieldEndLabelText: 'Bitiş',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: widget.seed),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      _start = dateOnly(picked.start);
      _end = dateOnly(picked.end);
      _presetId = _matchPreset();
    });
  }

  void _submit() {
    Navigator.pop(
      context,
      DateRangeFilterValue(DateTimeRange(start: dateOnly(_start), end: dateOnly(_end))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Material(
            color: cream,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tarih aralığı',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Rezervasyonları aralığa göre sorgulayın',
                    style: TextStyle(color: muted),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final preset in _presets)
                        ChoiceChip(
                          label: Text(preset.label),
                          selected: _presetId == preset.id,
                          selectedColor: widget.seed.withValues(alpha: 0.16),
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _presetId == preset.id ? widget.seed : ink,
                          ),
                          side: BorderSide(
                            color: _presetId == preset.id ? widget.seed.withValues(alpha: 0.4) : const Color(0xFFE5E7EB),
                          ),
                          onSelected: (_) => _applyPreset(preset),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _DateTile(label: 'Başlangıç', value: _dateFormat.format(_start), onTap: _pickRange)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, size: 18, color: muted),
                      ),
                      Expanded(child: _DateTile(label: 'Bitiş', value: _dateFormat.format(_end), onTap: _pickRange)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.search),
                    label: const Text('Sorgula'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context, const DateRangeFilterValue(null)),
                    child: const Text('Filtreyi temizle'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ink)),
            ],
          ),
        ),
      ),
    );
  }
}
