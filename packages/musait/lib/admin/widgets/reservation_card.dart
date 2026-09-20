import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import 'package:musait/theme.dart';

class ReservationCard extends StatelessWidget {
  const ReservationCard({
    super.key,
    required this.reservation,
    this.onTap,
    this.onCancel,
    this.compact = false,
  });

  final Reservation reservation;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(reservation.color);
    final dateFormat = DateFormat('d MMM', 'tr');
    final range = reservation.startDate == reservation.endDate
        ? dateFormat.format(reservation.startDate)
        : '${dateFormat.format(reservation.startDate)} – ${dateFormat.format(reservation.endDate)}';
    final time = reservation.startTime;
    final detail = [
      if (!compact) range,
      ?time,
      ?reservation.resourceName,
    ].join(' · ');
    final cancelled = reservation.isCancelled;

    return Dismissible(
      key: ValueKey(reservation.id),
      direction: onCancel == null || cancelled ? DismissDirection.none : DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('İptal edilsin mi?'),
                content: Text('${reservation.guestName} kaydı iptal olacak. Takvimde yer açılır.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('İptal et')),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => onCancel?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.event_busy, color: Colors.white),
      ),
      child: Material(
        color: cancelled ? const Color(0xFFF3F4F6) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cancelled ? const Color(0xFF9CA3AF) : color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reservation.guestName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: cancelled ? muted : ink,
                          decoration: cancelled ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (detail.isNotEmpty)
                        Text(detail, style: const TextStyle(color: muted, fontSize: 13)),
                    ],
                  ),
                ),
                Text(
                  reservation.statusLabel,
                  style: TextStyle(
                    color: colorFromHex(reservation.statusColor),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
