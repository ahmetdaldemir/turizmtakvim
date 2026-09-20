import 'package:flutter/material.dart';

import '../models/models.dart';
import '../models/session.dart';
import '../widgets/reservation_card.dart';
import 'reservation_form_screen.dart';

class ReservationsListScreen extends StatefulWidget {
  const ReservationsListScreen({super.key, required this.session});

  final SessionController session;

  @override
  State<ReservationsListScreen> createState() => _ReservationsListScreenState();
}

class _ReservationsListScreenState extends State<ReservationsListScreen> {
  late Future<List<Reservation>> _future;

  VerticalConfig get _vertical => widget.session.vertical!;

  @override
  void initState() {
    super.initState();
    _future = widget.session.api.fetchReservations();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.session.api.fetchReservations());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_vertical.listLabel)),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Reservation>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('${snapshot.error}'))]);
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return ListView(children: const [SizedBox(height: 80), Center(child: Text('Kayıt yok.'))]);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return ReservationCard(
                  reservation: item,
                  onTap: () async {
                    final saved = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReservationFormScreen(
                          session: widget.session,
                          draft: ReservationDraft.fromReservation(item),
                        ),
                      ),
                    );
                    if (saved == true) await _reload();
                  },
                  onCancel: item.isCancelled
                      ? null
                      : () async {
                          await widget.session.api.cancelReservation(item.id);
                          await _reload();
                        },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
