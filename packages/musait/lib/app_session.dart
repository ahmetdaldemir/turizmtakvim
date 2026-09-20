import 'package:flutter/material.dart';

import 'admin/models/session.dart';
import 'customer/session.dart';

enum LoginKind { business, customer }

class AppSession extends ChangeNotifier {
  AppSession() {
    admin.addListener(notifyListeners);
    customer.addListener(notifyListeners);
  }

  final admin = SessionController();
  final customer = CustomerSession();

  bool get restoring => admin.restoring || customer.restoring;
  bool get isBusiness => admin.isLoggedIn;
  bool get isCustomer => customer.isLoggedIn && !admin.isLoggedIn;

  Future<void> restore() async {
    await Future.wait([admin.restore(), customer.restore()]);
  }

  Future<void> login({
    required LoginKind kind,
    required String email,
    required String password,
  }) async {
    if (kind == LoginKind.business) {
      if (customer.isLoggedIn) await customer.logout();
      await admin.login(email, password);
      return;
    }
    if (admin.isLoggedIn) await admin.logout();
    await customer.login(email, password);
  }

  Future<void> logout() async {
    if (admin.isLoggedIn) await admin.logout();
    if (customer.isLoggedIn) await customer.logout();
  }
}
