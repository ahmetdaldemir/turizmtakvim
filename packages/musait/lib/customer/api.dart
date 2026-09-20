import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:musait/config.dart';
import 'package:musait/gallery.dart';
import 'models.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ApiService {
  ApiService() : _baseUrl = AppConfig.baseUrl;
  final String _baseUrl;
  final _client = http.Client();
  String? token;

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: query);

  Future<Map<String, dynamic>> login(String email, String password) async {
    return await _send('POST', _uri('/api/customer/auth/login'), {
          'email': email,
          'password': password,
          'sector': AppConfig.sector,
        })
        as Map<String, dynamic>;
  }

  Future<List<Business>> businesses({String? type}) async {
    final data = await _get(_uri('/api/public/businesses'));
    return (data as List).map((item) => Business.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> availability({
    required int businessId,
    required int year,
    required int month,
    int? resourceId,
  }) async {
    final query = {'year': '$year', 'month': '$month'};
    if (resourceId != null) query['resourceId'] = '$resourceId';
    return await _get(_uri('/api/public/businesses/$businessId/availability', query))
        as Map<String, dynamic>;
  }

  Future<void> createRequest(Map<String, dynamic> body) async {
    await _send('POST', _uri('/api/customer/requests'), body);
  }

  Future<List<BookingRequest>> myRequests() async {
    final data = await _get(_uri('/api/customer/requests'));
    return (data as List)
        .map((item) => BookingRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<BookingRequest> updateRequest(int id, Map<String, dynamic> body) async {
    final data = await _send('PATCH', _uri('/api/customer/requests/$id'), body);
    return BookingRequest.fromJson(data as Map<String, dynamic>);
  }

  Future<List<GalleryAlbum>> albums() async {
    final data = await _get(_uri('/api/customer/gallery/albums'));
    return (data as List).map((item) => GalleryAlbum.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<GalleryAlbum> album(int id) async {
    final data = await _get(_uri('/api/customer/gallery/albums/$id'));
    return GalleryAlbum.fromJson(data as Map<String, dynamic>);
  }

  Future<BookingRequest> cancelRequest(int id) async {
    final data = await _send('POST', _uri('/api/customer/requests/$id/cancel'), {});
    return BookingRequest.fromJson(data as Map<String, dynamic>);
  }

  Future<dynamic> _get(Uri uri) async {
    try {
      final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 12));
      if (response.statusCode >= 200 && response.statusCode < 300) return jsonDecode(response.body);
      throw _error(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Sunucuya bağlanılamadı.');
    }
  }

  Future<dynamic> _send(String method, Uri uri, Map<String, dynamic> body) async {
    try {
      final request = http.Request(method, uri)
        ..headers.addAll(_headers)
        ..body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 12)),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.body.isEmpty ? null : jsonDecode(response.body);
      }
      throw _error(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Sunucuya bağlanılamadı.');
    }
  }

  ApiException _error(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] is String) return ApiException(body['error'] as String);
    } catch (_) {}
    return ApiException('İstek başarısız (${response.statusCode}).');
  }
}
