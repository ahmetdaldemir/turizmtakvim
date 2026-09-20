import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:musait/config.dart';
import 'api_service.dart';
import 'models.dart';

class SessionController extends ChangeNotifier {
  SessionController({ApiService? api}) : api = api ?? ApiService();

  final ApiService api;
  SessionUser? user;
  var restoring = true;

  bool get isLoggedIn => user != null && api.token != null;
  VerticalConfig? get vertical => user?.vertical;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('admin_token');
    final raw = prefs.getString('admin_user');
    if (token != null && raw != null) {
      api.token = token;
      user = SessionUser.fromJson(asJsonMap(jsonDecode(raw)));
      if (AppConfig.locksSector && !user!.isSuperAdmin && user!.vertical?.key != AppConfig.sector) {
        api.token = null;
        user = null;
        await prefs.remove('admin_token');
        await prefs.remove('admin_user');
      } else {
        try {
          final me = await api.fetchMe();
          user = SessionUser.fromJson(asJsonMap(me['user']));
          await prefs.setString('admin_user', jsonEncode(me['user']));
        } catch (_) {
          api.token = null;
          user = null;
          await prefs.remove('admin_token');
          await prefs.remove('admin_user');
        }
      }
    }
    restoring = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final data = await api.login(email, password);
    final sessionUser = SessionUser.fromJson(asJsonMap(data['user']));
    if (!sessionUser.isSuperAdmin && sessionUser.vertical == null) {
      throw ApiException('Bu uygulama işletme yöneticileri içindir.');
    }
    if (AppConfig.locksSector &&
        !sessionUser.isSuperAdmin &&
        sessionUser.vertical?.key != AppConfig.sector) {
      final other = sessionUser.vertical?.key == 'kuafor' ? 'Kuaför Yönetim' : 'Villa Yönetim';
      throw ApiException('Bu hesap $other uygulamasına aittir.');
    }
    api.token = data['token'] as String;
    user = sessionUser;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_token', api.token!);
    await prefs.setString('admin_user', jsonEncode(data['user']));
    notifyListeners();
  }

  Future<void> logout() async {
    await api.logout();
    api.token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_token');
    await prefs.remove('admin_user');
    notifyListeners();
  }

  Future<void> updateProfile({
    required String name,
    required String email,
    String currentPassword = '',
    String newPassword = '',
  }) async {
    final data = await api.updateProfile(
      name: name,
      email: email,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    user = SessionUser.fromJson(asJsonMap(data['user']));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_user', jsonEncode(data['user']));
    notifyListeners();
  }
}
