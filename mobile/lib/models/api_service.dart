import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'models.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? AppConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;
  String? token;

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$_baseUrl$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await _send('POST', _uri('/api/auth/login'), {
      'email': email,
      'password': password,
    });
    return asJsonMap(data);
  }

  Future<void> logout() async {
    try {
      await _send('POST', _uri('/api/auth/logout'), {});
    } catch (_) {}
  }

  Future<Map<String, dynamic>> fetchMe() async {
    return asJsonMap(await _get(_uri('/api/auth/me')));
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String email,
    String currentPassword = '',
    String newPassword = '',
  }) async {
    final body = <String, dynamic>{'name': name, 'email': email};
    if (currentPassword.isNotEmpty) body['currentPassword'] = currentPassword;
    if (newPassword.isNotEmpty) body['newPassword'] = newPassword;
    return asJsonMap(await _send('PATCH', _uri('/api/auth/profile'), body));
  }

  Future<void> forgotPassword(String email) async {
    await _send('POST', _uri('/api/auth/forgot-password'), {'email': email});
  }

  Future<void> resetPassword(String token, String password) async {
    await _send('POST', _uri('/api/auth/reset-password'), {
      'token': token,
      'password': password,
    });
  }

  Future<List<TenantAccount>> fetchTenants() async {
    final data = await _get(_uri('/api/panel/tenants'));
    return (data as List)
        .map((item) => TenantAccount.fromJson(asJsonMap(item)))
        .toList();
  }

  Future<TenantAccount> createTenant({
    required String name,
    required String type,
    required String ownerName,
    required String ownerEmail,
    required String ownerPassword,
  }) async {
    final data = await _send('POST', _uri('/api/panel/tenants'), {
      'name': name,
      'type': type,
      'ownerName': ownerName,
      'ownerEmail': ownerEmail,
      'ownerPassword': ownerPassword,
    });
    return TenantAccount.fromJson(asJsonMap(data));
  }

  Future<List<ManagedCustomer>> fetchCustomers() async {
    final data = await _get(_uri('/api/customers'));
    return (data as List)
        .map((item) => ManagedCustomer.fromJson(asJsonMap(item)))
        .toList();
  }

  Future<ManagedCustomer> createCustomer({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final data = await _send('POST', _uri('/api/customers'), {
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
    });
    return ManagedCustomer.fromJson(asJsonMap(data));
  }

  Future<void> deleteCustomer(int id) async {
    final response = await _client
        .delete(_uri('/api/customers/$id'), headers: _headers)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 204) throw _errorFrom(response);
  }

  Future<List<Reservation>> fetchReservations({DateTime? from, DateTime? to}) async {
    final query = <String, String>{};
    if (from != null) query['from'] = isoDate(from);
    if (to != null) query['to'] = isoDate(to);
    final data = await _get(_uri('/api/reservations', query.isEmpty ? null : query));
    return (data as List)
        .map((item) => Reservation.fromJson(asJsonMap(item)))
        .toList();
  }

  Future<List<ResourceItem>> fetchResources() async {
    final data = await _get(_uri('/api/resources'));
    return (data as List)
        .map((item) => ResourceItem.fromJson(asJsonMap(item)))
        .toList();
  }

  Future<ResourceItem> createResource({
    required String name,
    required String region,
    String? description,
  }) async {
    final data = await _send('POST', _uri('/api/resources'), {
      'name': name,
      'region': region,
      'description': description,
    });
    return ResourceItem.fromJson(asJsonMap(data));
  }

  Future<ResourceItem> updateResource({
    required int id,
    required String name,
    required String region,
    String? description,
  }) async {
    final data = await _send('PUT', _uri('/api/resources/$id'), {
      'name': name,
      'region': region,
      'description': description,
    });
    return ResourceItem.fromJson(asJsonMap(data));
  }

  Future<void> deleteResource(int id) async {
    final response = await _client
        .delete(_uri('/api/resources/$id'), headers: _headers)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 204) throw _errorFrom(response);
  }

  Future<Reservation> createReservation(ReservationDraft draft) async {
    final data = await _send('POST', _uri('/api/reservations'), draft.toJson());
    return Reservation.fromJson(asJsonMap(data));
  }

  Future<Reservation> updateReservation(ReservationDraft draft) async {
    final data = await _send('PUT', _uri('/api/reservations/${draft.id}'), draft.toJson());
    return Reservation.fromJson(asJsonMap(data));
  }

  Future<Reservation> cancelReservation(int id) async {
    final data = await _send('POST', _uri('/api/reservations/$id/cancel'), {});
    return Reservation.fromJson(asJsonMap(data));
  }

  Future<void> deleteReservation(int id) async {
    final response = await _client
        .delete(_uri('/api/reservations/$id'), headers: _headers)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 204) throw _errorFrom(response);
  }

  Future<List<BookingRequest>> fetchRequests() async {
    final data = await _get(_uri('/api/requests'));
    return (data as List)
        .map((item) => BookingRequest.fromJson(asJsonMap(item)))
        .toList();
  }

  Future<void> approveRequest(int id) async {
    await _send('POST', _uri('/api/requests/$id/approve'), {});
  }

  Future<void> rejectRequest(int id, String reason) async {
    await _send('POST', _uri('/api/requests/$id/reject'), {'reason': reason});
  }

  Future<int> unreadCount() async {
    final data = await _get(_uri('/api/notifications/unread-count'));
    return asIntOrNull(asJsonMap(data)['count']) ?? 0;
  }

  Future<List<AppNotification>> fetchNotifications() async {
    final data = await _get(_uri('/api/notifications'));
    return (data as List)
        .map((item) => AppNotification.fromJson(asJsonMap(item)))
        .toList();
  }

  Future<void> markAllRead() async {
    await _send('POST', _uri('/api/notifications/read-all'), {});
  }

  Future<dynamic> _get(Uri uri) async {
    try {
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      }
      throw _errorFrom(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Sunucuya bağlanılamadı. API: $_baseUrl');
    }
  }

  Future<dynamic> _send(String method, Uri uri, Map<String, dynamic> body) async {
    try {
      final request = http.Request(method, uri)
        ..headers.addAll(_headers)
        ..body = jsonEncode(body);
      final streamed = await _client.send(request).timeout(const Duration(seconds: 12));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return null;
        return jsonDecode(response.body);
      }
      throw _errorFrom(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Sunucuya bağlanılamadı. API: $_baseUrl');
    }
  }

  ApiException _errorFrom(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] is String) {
        return ApiException(body['error'] as String);
      }
    } catch (_) {}
    return ApiException('İstek başarısız (${response.statusCode}).');
  }
}
