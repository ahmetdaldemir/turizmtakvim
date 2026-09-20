Map<String, dynamic> asJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Geçersiz yanıt.');
}

Map<String, dynamic>? asJsonMapOrNull(dynamic value) {
  if (value == null) return null;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

int asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.parse('$value');
}

int? asIntOrNull(dynamic value) => value == null ? null : asInt(value);

class VerticalConfig {
  const VerticalConfig({
    required this.key,
    required this.label,
    required this.appTitle,
    required this.customerLabel,
    required this.resourceLabel,
    required this.resourcePlural,
    required this.addLabel,
    required this.listLabel,
    required this.emptyDay,
    required this.dateMode,
    required this.timeEnabled,
    required this.primaryColor,
    required this.types,
  });

  final String key;
  final String label;
  final String appTitle;
  final String customerLabel;
  final String resourceLabel;
  final String resourcePlural;
  final String addLabel;
  final String listLabel;
  final String emptyDay;
  final String dateMode;
  final bool timeEnabled;
  final String primaryColor;
  final Map<String, ServiceType> types;

  bool get isRange => dateMode == 'range';
  bool get hasTypeChoice => types.length > 1;

  factory VerticalConfig.fromJson(Map<String, dynamic> json) {
    final rawTypes = asJsonMapOrNull(json['types']) ?? {};
    return VerticalConfig(
      key: json['key'] as String,
      label: json['label'] as String,
      appTitle: json['appTitle'] as String,
      customerLabel: json['customerLabel'] as String,
      resourceLabel: json['resourceLabel'] as String,
      resourcePlural: json['resourcePlural'] as String,
      addLabel: json['addLabel'] as String,
      listLabel: json['listLabel'] as String,
      emptyDay: json['emptyDay'] as String,
      dateMode: json['dateMode'] as String,
      timeEnabled: json['timeEnabled'] as bool? ?? false,
      primaryColor: json['primaryColor'] as String? ?? '#0F766E',
      types: rawTypes.map(
        (key, value) => MapEntry(key, ServiceType.fromJson(key, asJsonMap(value))),
      ),
    );
  }
}

class ServiceType {
  const ServiceType({
    required this.key,
    required this.label,
    required this.color,
    this.durationMin,
  });

  final String key;
  final String label;
  final String color;
  final int? durationMin;

  factory ServiceType.fromJson(String key, Map<String, dynamic> json) {
    return ServiceType(
      key: key,
      label: json['label'] as String,
      color: json['color'] as String,
      durationMin: asIntOrNull(json['durationMin']),
    );
  }
}

class SessionUser {
  const SessionUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.tenantId,
    this.tenantName,
    this.vertical,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final int? tenantId;
  final String? tenantName;
  final VerticalConfig? vertical;

  bool get isSuperAdmin => role == 'super_admin';

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    final tenant = asJsonMapOrNull(json['tenant']);
    final vertical = asJsonMapOrNull(json['vertical']);
    return SessionUser(
      id: asInt(json['id']),
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      tenantId: asIntOrNull(json['tenantId']),
      tenantName: tenant?['name'] as String?,
      vertical: vertical == null ? null : VerticalConfig.fromJson(vertical),
    );
  }
}

class ResourceItem {
  const ResourceItem({
    required this.id,
    required this.name,
    required this.color,
    this.region,
    this.description,
  });

  final int id;
  final String name;
  final String color;
  final String? region;
  final String? description;

  String get subtitle {
    final parts = [region, description].whereType<String>().where((value) => value.isNotEmpty);
    return parts.join(' · ');
  }

  factory ResourceItem.fromJson(Map<String, dynamic> json) {
    return ResourceItem(
      id: asInt(json['id']),
      name: json['name'] as String,
      color: json['color'] as String? ?? '#0D9488',
      region: json['region'] as String?,
      description: json['description'] as String?,
    );
  }
}

class Reservation {
  const Reservation({
    required this.id,
    required this.guestName,
    required this.startDate,
    required this.endDate,
    required this.type,
    required this.typeLabel,
    required this.color,
    required this.status,
    required this.statusLabel,
    required this.statusColor,
    this.phone,
    this.email,
    this.notes,
    this.resourceId,
    this.resourceName,
    this.startTime,
    this.durationMin,
  });

  final int id;
  final String guestName;
  final String? phone;
  final String? email;
  final DateTime startDate;
  final DateTime endDate;
  final String type;
  final String typeLabel;
  final String color;
  final String status;
  final String statusLabel;
  final String statusColor;
  final String? notes;
  final int? resourceId;
  final String? resourceName;
  final String? startTime;
  final int? durationMin;

  bool get isCancelled => status == 'iptal';

  bool covers(DateTime day) {
    final date = dateOnly(day);
    return !date.isBefore(startDate) && !date.isAfter(endDate);
  }

  bool overlaps(DateTime from, DateTime to) {
    final start = dateOnly(from);
    final end = dateOnly(to);
    return !endDate.isBefore(start) && !startDate.isAfter(end);
  }

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: asInt(json['id']),
      guestName: json['guestName'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      startDate: dateOnly(DateTime.parse(json['startDate'] as String)),
      endDate: dateOnly(DateTime.parse(json['endDate'] as String)),
      type: json['type'] as String,
      typeLabel: json['typeLabel'] as String,
      color: json['color'] as String,
      status: json['status'] as String,
      statusLabel: json['statusLabel'] as String,
      statusColor: json['statusColor'] as String,
      notes: json['notes'] as String?,
      resourceId: asIntOrNull(json['resourceId']),
      resourceName: json['resourceName'] as String?,
      startTime: json['startTime'] as String?,
      durationMin: asIntOrNull(json['durationMin']),
    );
  }
}

class ReservationDraft {
  ReservationDraft({
    this.id,
    this.guestName = '',
    this.phone = '',
    this.email = '',
    DateTime? startDate,
    DateTime? endDate,
    this.type = '',
    this.status = 'onaylandi',
    this.notes = '',
    this.resourceId,
    this.startTime = '10:00',
    this.durationMin = 60,
  }) : startDate = dateOnly(startDate ?? DateTime.now()),
       endDate = dateOnly(endDate ?? DateTime.now());

  final int? id;
  String guestName;
  String phone;
  String email;
  DateTime startDate;
  DateTime endDate;
  String type;
  String status;
  String notes;
  int? resourceId;
  String startTime;
  int durationMin;

  factory ReservationDraft.fromReservation(Reservation item) {
    return ReservationDraft(
      id: item.id,
      guestName: item.guestName,
      phone: item.phone ?? '',
      email: item.email ?? '',
      startDate: item.startDate,
      endDate: item.endDate,
      type: item.type,
      status: item.status,
      notes: item.notes ?? '',
      resourceId: item.resourceId,
      startTime: item.startTime ?? '10:00',
      durationMin: item.durationMin ?? 60,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'guestName': guestName.trim(),
      'phone': phone.trim().isEmpty ? null : phone.trim(),
      'email': email.trim().isEmpty ? null : email.trim(),
      'startDate': isoDate(startDate),
      'endDate': isoDate(endDate),
      'type': type,
      'status': status,
      'notes': notes.trim().isEmpty ? null : notes.trim(),
      'resourceId': resourceId,
      'startTime': startTime,
      'durationMin': durationMin,
    };
  }
}

class BookingRequest {
  const BookingRequest({
    required this.id,
    required this.guestName,
    required this.startDate,
    required this.endDate,
    required this.typeLabel,
    required this.status,
    required this.statusLabel,
    required this.statusColor,
    required this.color,
    this.phone,
    this.resourceName,
    this.startTime,
    this.notes,
  });

  final int id;
  final String guestName;
  final DateTime startDate;
  final DateTime endDate;
  final String typeLabel;
  final String status;
  final String statusLabel;
  final String statusColor;
  final String color;
  final String? phone;
  final String? resourceName;
  final String? startTime;
  final String? notes;

  bool get isPending => status == 'pending';

  bool overlapsRange(DateTime from, DateTime to) {
    final start = dateOnly(from);
    final end = dateOnly(to);
    return !endDate.isBefore(start) && !startDate.isAfter(end);
  }

  factory BookingRequest.fromJson(Map<String, dynamic> json) {
    return BookingRequest(
      id: asInt(json['id']),
      guestName: json['guestName'] as String,
      startDate: dateOnly(DateTime.parse(json['startDate'] as String)),
      endDate: dateOnly(DateTime.parse(json['endDate'] as String)),
      typeLabel: json['typeLabel'] as String,
      status: json['status'] as String,
      statusLabel: json['statusLabel'] as String,
      statusColor: json['statusColor'] as String,
      color: json['color'] as String? ?? '#D97706',
      phone: json['phone'] as String?,
      resourceName: json['resourceName'] as String?,
      startTime: json['startTime'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: asInt(json['id']),
      title: json['title'] as String,
      body: json['body'] as String,
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class TenantAccount {
  const TenantAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.typeLabel,
    required this.status,
    this.ownerName,
    this.ownerEmail,
    this.customerCount = 0,
  });

  final int id;
  final String name;
  final String type;
  final String typeLabel;
  final String status;
  final String? ownerName;
  final String? ownerEmail;
  final int customerCount;

  factory TenantAccount.fromJson(Map<String, dynamic> json) {
    return TenantAccount(
      id: asInt(json['id']),
      name: json['name'] as String,
      type: json['type'] as String,
      typeLabel: json['typeLabel'] as String? ?? json['type'] as String,
      status: json['status'] as String? ?? 'active',
      ownerName: json['ownerName'] as String?,
      ownerEmail: json['ownerEmail'] as String?,
      customerCount: asIntOrNull(json['customerCount']) ?? 0,
    );
  }
}

class ManagedCustomer {
  const ManagedCustomer({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.sectorLabel,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? sectorLabel;

  factory ManagedCustomer.fromJson(Map<String, dynamic> json) {
    return ManagedCustomer(
      id: asInt(json['id']),
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      sectorLabel: json['sectorLabel'] as String?,
    );
  }
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String isoDate(DateTime date) {
  final normalized = dateOnly(date);
  final y = normalized.year.toString().padLeft(4, '0');
  final m = normalized.month.toString().padLeft(2, '0');
  final d = normalized.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

const reservationStatuses = <String, String>{
  'beklemede': 'Beklemede',
  'onaylandi': 'Onaylandı',
  'iptal': 'İptal',
};
