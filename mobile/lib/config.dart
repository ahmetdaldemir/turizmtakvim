import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppConfig {
  static const _defined = String.fromEnvironment('API_BASE_URL');
  static const lanIp = String.fromEnvironment('LAN_IP');
  static const sector = String.fromEnvironment('SECTOR');
  static const productionUrl = 'https://musaitvillam.com';

  static bool get isKuafor => sector == 'kuafor';
  static bool get isVilla => sector == 'villa';
  static bool get locksSector => isKuafor || isVilla;
  static String get sectorLabel => isKuafor ? 'kuaför' : 'villa';
  static String get appTitle => isKuafor
      ? 'Kuaför Yönetim'
      : isVilla
      ? 'Villa Yönetim'
      : 'Yönetim';
  static Color get seedColor => isKuafor ? const Color(0xFFBE185D) : const Color(0xFF0F766E);

  static String get baseUrl {
    if (_defined.isNotEmpty) {
      return _defined;
    }
    if (kReleaseMode) {
      return productionUrl;
    }
    if (lanIp.isNotEmpty) {
      return 'http://$lanIp:3000';
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:3000';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://127.0.0.1:3000';
  }
}
