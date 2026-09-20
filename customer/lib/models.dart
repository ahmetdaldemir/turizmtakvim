class Business {
  const Business({
    required this.id,
    required this.name,
    required this.type,
    required this.typeLabel,
  });

  final int id;
  final String name;
  final String type;
  final String typeLabel;

  factory Business.fromJson(Map<String, dynamic> json) {
    return Business(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] as String,
      typeLabel: json['typeLabel'] as String,
    );
  }
}

class ResourceItem {
  const ResourceItem({required this.id, required this.name, this.region});
  final int id;
  final String name;
  final String? region;
  factory ResourceItem.fromJson(Map<String, dynamic> json) {
    return ResourceItem(
      id: json['id'] as int,
      name: json['name'] as String,
      region: json['region'] as String?,
    );
  }

  String get label => region == null || region!.isEmpty ? name : '$name · $region';
}

class VerticalConfig {
  const VerticalConfig({
    required this.key,
    required this.customerLabel,
    required this.resourceLabel,
    required this.timeEnabled,
    required this.dateMode,
    required this.types,
    required this.slots,
  });

  final String key;
  final String customerLabel;
  final String resourceLabel;
  final bool timeEnabled;
  final String dateMode;
  final Map<String, String> types;
  final List<String> slots;

  factory VerticalConfig.fromJson(Map<String, dynamic> json, List<dynamic> slots) {
    final raw = json['types'] as Map<String, dynamic>? ?? {};
    return VerticalConfig(
      key: json['key'] as String,
      customerLabel: json['customerLabel'] as String? ?? 'Müşteri',
      resourceLabel: json['resourceLabel'] as String? ?? 'Kaynak',
      timeEnabled: json['timeEnabled'] as bool? ?? false,
      dateMode: json['dateMode'] as String? ?? 'single',
      types: raw.map((key, value) => MapEntry(key, (value as Map)['label'] as String)),
      slots: slots.map((item) => item.toString()).toList(),
    );
  }
}

class BookingRequest {
  const BookingRequest({
    required this.id,
    required this.tenantId,
    required this.tenantName,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.statusLabel,
    required this.statusColor,
    this.resourceId,
    this.resourceName,
    this.startTime,
    this.type,
    this.typeLabel,
    this.notes,
    this.canEdit = false,
    this.canCancel = false,
  });

  final int id;
  final int tenantId;
  final String tenantName;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String statusLabel;
  final String statusColor;
  final int? resourceId;
  final String? resourceName;
  final String? startTime;
  final String? type;
  final String? typeLabel;
  final String? notes;
  final bool canEdit;
  final bool canCancel;

  factory BookingRequest.fromJson(Map<String, dynamic> json) {
    return BookingRequest(
      id: json['id'] as int,
      tenantId: json['tenantId'] as int,
      tenantName: json['tenantName'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      status: json['status'] as String? ?? '',
      statusLabel: json['statusLabel'] as String,
      statusColor: json['statusColor'] as String,
      resourceId: json['resourceId'] as int?,
      resourceName: json['resourceName'] as String?,
      startTime: json['startTime'] as String?,
      type: json['type'] as String?,
      typeLabel: json['typeLabel'] as String?,
      notes: json['notes'] as String?,
      canEdit: json['canEdit'] as bool? ?? false,
      canCancel: json['canCancel'] as bool? ?? false,
    );
  }
}

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.sector,
    this.tenantId,
    this.tenant,
  });

  final int id;
  final String name;
  final String email;
  final String sector;
  final int? tenantId;
  final Business? tenant;

  factory Customer.fromJson(Map<String, dynamic> json) {
    final tenant = json['tenant'] as Map<String, dynamic>?;
    return Customer(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      sector: json['sector'] as String? ?? '',
      tenantId: json['tenantId'] as int?,
      tenant: tenant == null ? null : Business.fromJson(tenant),
    );
  }
}

String isoDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
