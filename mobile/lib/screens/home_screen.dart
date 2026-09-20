import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../config.dart';
import '../models/models.dart';
import '../models/session.dart';
import '../theme.dart';
import '../widgets/date_range_filter_sheet.dart';
import '../widgets/reservation_card.dart';
import 'admin_shell.dart';
import 'reservation_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.session,
    this.onChanged,
    this.onOpenRequests,
  });

  final SessionController session;
  final VoidCallback? onChanged;
  final VoidCallback? onOpenRequests;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  DateTime? _filterStart;
  DateTime? _filterEnd;
  List<Reservation> _reservations = [];
  List<Reservation> _queryHits = [];
  List<BookingRequest> _pending = [];
  var _loading = true;
  var _querying = false;
  String? _error;

  VerticalConfig get _vertical => widget.session.vertical!;
  bool get _hasFilter => _filterStart != null && _filterEnd != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Reservation> _markersFor(DateTime day) {
    return _reservations.where((item) => !item.isCancelled && item.covers(day)).toList();
  }

  List<Reservation> _eventsFor(DateTime day) {
    final items = _reservations.where((item) => item.covers(day)).toList();
    items.sort((a, b) => (a.isCancelled ? 1 : 0).compareTo(b.isCancelled ? 1 : 0));
    return items;
  }

  List<BookingRequest> _pendingFor(DateTime day) {
    final date = dateOnly(day);
    return _pending.where((item) {
      return !date.isBefore(item.startDate) && !date.isAfter(item.endDate);
    }).toList();
  }

  List<Reservation> get _visibleReservations {
    if (!_hasFilter) return _eventsFor(_selectedDay);
    return _queryHits;
  }

  Future<void> _load({bool spinner = true}) async {
    setState(() {
      if (spinner) _loading = true;
      _error = null;
    });
    try {
      final items = await widget.session.api.fetchReservations();
      final requests = await widget.session.api.fetchRequests();
      List<Reservation> hits = _queryHits;
      if (_hasFilter) {
        hits = await widget.session.api.fetchReservations(from: _filterStart, to: _filterEnd);
      }
      if (!mounted) return;
      setState(() {
        _reservations = items;
        _queryHits = hits;
        _pending = requests.where((item) => item.isPending).toList();
        _loading = false;
      });
      widget.onChanged?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openFilter() async {
    final seed = colorFromHex(_vertical.primaryColor);
    final result = await showDateRangeFilterSheet(
      context: context,
      seed: seed,
      initial: _hasFilter ? DateTimeRange(start: _filterStart!, end: _filterEnd!) : null,
    );
    if (result == null || !mounted) return;

    if (result.cleared) {
      await _clearFilter();
      return;
    }

    setState(() {
      _filterStart = result.range!.start;
      _filterEnd = result.range!.end;
      _querying = true;
      _error = null;
      _selectedDay = _filterStart!;
      _focusedDay = _filterStart!;
    });
    try {
      final hits = await widget.session.api.fetchReservations(
        from: _filterStart,
        to: _filterEnd,
      );
      if (!mounted) return;
      setState(() {
        _queryHits = hits;
        _querying = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _querying = false;
        _filterStart = null;
        _filterEnd = null;
        _queryHits = [];
      });
    }
  }

  Future<void> _clearFilter() async {
    setState(() {
      _filterStart = null;
      _filterEnd = null;
      _queryHits = [];
      _querying = false;
    });
  }

  Future<void> _openCreate() async {
    final selected = dateOnly(_selectedDay);
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReservationFormScreen(
          session: widget.session,
          draft: ReservationDraft(
            startDate: selected,
            endDate: selected,
            type: _vertical.types.keys.first,
          ),
        ),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _openEdit(Reservation reservation) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReservationFormScreen(
          session: widget.session,
          draft: ReservationDraft.fromReservation(reservation),
        ),
      ),
    );
    if (saved == true) await _load();
  }

  String _rangeTitle() {
    final format = DateFormat('d MMM', 'tr');
    if (!_hasFilter) {
      final isToday = isSameDay(_selectedDay, DateTime.now());
      return isToday ? 'Bugün' : DateFormat('d MMMM', 'tr').format(_selectedDay);
    }
    if (isSameDay(_filterStart, _filterEnd)) {
      return DateFormat('d MMMM yyyy', 'tr').format(_filterStart!);
    }
    return '${format.format(_filterStart!)} – ${format.format(_filterEnd!)}';
  }

  @override
  Widget build(BuildContext context) {
    final selectedPending = _hasFilter
        ? _pending.where((item) => item.overlapsRange(_filterStart!, _filterEnd!)).toList()
        : _pendingFor(_selectedDay);
    final visible = _visibleReservations;
    final seed = colorFromHex(_vertical.primaryColor);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Ekle'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            PanelHeader(
              title: widget.session.user?.tenantName ?? _vertical.appTitle,
              subtitle: _vertical.label,
              session: widget.session,
              onRefresh: _load,
              onLogout: widget.session.logout,
              actions: [
                FilledButton.tonalIcon(
                  onPressed: _openFilter,
                  icon: const Icon(Icons.search, size: 18),
                  label: Text(_hasFilter ? 'Filtre' : 'Filtrele'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text('API: ${AppConfig.baseUrl}', textAlign: TextAlign.center, style: const TextStyle(color: muted)),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Tekrar dene')),
                      ],
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        children: [
                          TableCalendar<Reservation>(
                            locale: 'tr_TR',
                            firstDay: DateTime.utc(2020, 1, 1),
                            lastDay: DateTime.utc(2035, 12, 31),
                            focusedDay: _focusedDay,
                            selectedDayPredicate: (day) => !_hasFilter && isSameDay(_selectedDay, day),
                            rangeStartDay: _filterStart,
                            rangeEndDay: _filterEnd,
                            rangeSelectionMode: RangeSelectionMode.toggledOff,
                            eventLoader: _markersFor,
                            startingDayOfWeek: StartingDayOfWeek.monday,
                            rowHeight: 44,
                            daysOfWeekHeight: 22,
                            headerStyle: const HeaderStyle(
                              titleCentered: true,
                              formatButtonVisible: false,
                              titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              leftChevronMargin: EdgeInsets.zero,
                              rightChevronMargin: EdgeInsets.zero,
                              headerPadding: EdgeInsets.only(bottom: 4),
                            ),
                            calendarStyle: CalendarStyle(
                              cellMargin: const EdgeInsets.all(2),
                              todayDecoration: BoxDecoration(
                                color: seed.withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                              ),
                              todayTextStyle: TextStyle(color: seed, fontWeight: FontWeight.w700),
                              selectedDecoration: BoxDecoration(color: seed, shape: BoxShape.circle),
                              rangeStartDecoration: BoxDecoration(color: seed, shape: BoxShape.circle),
                              rangeEndDecoration: BoxDecoration(color: seed, shape: BoxShape.circle),
                              rangeHighlightColor: seed.withValues(alpha: 0.14),
                              markersMaxCount: 1,
                              markerSize: 5,
                              markerDecoration: BoxDecoration(color: seed, shape: BoxShape.circle),
                              outsideDaysVisible: false,
                            ),
                            calendarBuilders: CalendarBuilders(
                              markerBuilder: (context, day, events) {
                                final pending = _pendingFor(day);
                                if (events.isEmpty && pending.isEmpty) return const SizedBox.shrink();
                                return Positioned(
                                  bottom: 4,
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: pending.isNotEmpty ? const Color(0xFFD97706) : seed,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                );
                              },
                            ),
                            onDaySelected: (selected, focused) {
                              setState(() {
                                _selectedDay = selected;
                                _focusedDay = focused;
                                _filterStart = null;
                                _filterEnd = null;
                                _queryHits = [];
                              });
                            },
                            onPageChanged: (focused) => _focusedDay = focused,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _rangeTitle(),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                                ),
                              ),
                              if (_hasFilter)
                                TextButton(
                                  onPressed: _querying ? null : _clearFilter,
                                  child: const Text('Temizle'),
                                ),
                            ],
                          ),
                          if (_hasFilter)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                _querying ? 'Sorgulanıyor...' : '${visible.length} kayıt',
                                style: const TextStyle(color: muted, fontWeight: FontWeight.w600),
                              ),
                            ),
                          if (selectedPending.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Material(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                onTap: widget.onOpenRequests,
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.inbox_outlined, color: Color(0xFFD97706)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '${selectedPending.length} talep onay bekliyor',
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, color: muted),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          if (_querying)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 28),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (visible.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 28),
                              child: Text(
                                _hasFilter ? 'Bu aralıkta kayıt yok.' : _vertical.emptyDay,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: muted),
                              ),
                            )
                          else
                            ...visible.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: ReservationCard(
                                  reservation: item,
                                  compact: !_hasFilter,
                                  onTap: () => _openEdit(item),
                                  onCancel: item.isCancelled
                                      ? null
                                      : () async {
                                          await widget.session.api.cancelReservation(item.id);
                                          await _load();
                                        },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
