import 'package:flutter/material.dart';

class AppConfig {
  static String sector = 'villa';
  static String apiBase = 'https://musaitvillam.com';

  static void boot({required String sector, String apiBase = 'https://musaitvillam.com'}) {
    if (sector != 'villa' && sector != 'kuafor') {
      throw ArgumentError.value(sector, 'sector');
    }
    AppConfig.sector = sector;
    AppConfig.apiBase = apiBase;
  }

  static bool get isKuafor => sector == 'kuafor';
  static bool get locksSector => true;
  static String get sectorLabel => isKuafor ? 'kuaför' : 'villa';
  static String get appTitle => isKuafor ? 'Kuaför Randevu' : 'Müsait Villam';
  static Color get seedColor => isKuafor ? const Color(0xFFBE185D) : const Color(0xFF0F766E);
  static String get seedHex => isKuafor ? '#BE185D' : '#0F766E';
  static String get managerDemoEmail => isKuafor ? 'kuafor@takvim.app' : 'villa@takvim.app';
  static String get customerDemoEmail => isKuafor ? 'musteri@takvim.app' : 'villa.musteri@takvim.app';

  static String get baseUrl => apiBase;
}
