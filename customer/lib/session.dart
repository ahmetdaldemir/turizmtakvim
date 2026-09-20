import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'config.dart';
import 'models.dart';

class CustomerSession extends ChangeNotifier {
  final api = ApiService();
  Customer? user;
  var restoring = true;

  bool get isLoggedIn => user != null && api.token != null;

  String get _tokenKey => 'customer_token_${AppConfig.sector}';
  String get _userKey => 'customer_user_${AppConfig.sector}';

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final raw = prefs.getString(_userKey);
    if (token != null && raw != null) {
      final stored = Customer.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (stored.sector == AppConfig.sector) {
        api.token = token;
        user = stored;
      } else {
        await prefs.remove(_tokenKey);
        await prefs.remove(_userKey);
      }
    }
    restoring = false;
    notifyListeners();
  }

  Future<void> _store(Map<String, dynamic> data) async {
    final stored = Customer.fromJson(data['user'] as Map<String, dynamic>);
    if (stored.sector != AppConfig.sector) {
      throw ApiException('Bu hesap ${AppConfig.sectorLabel} uygulamasına ait değil.');
    }
    api.token = data['token'] as String;
    user = stored;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, api.token!);
    await prefs.setString(_userKey, jsonEncode(data['user']));
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    await _store(await api.login(email, password));
  }

  Future<void> logout() async {
    api.token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    notifyListeners();
  }
}
