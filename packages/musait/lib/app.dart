import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'admin/screens/admin_shell.dart';
import 'admin/screens/forgot_password_screen.dart';
import 'admin/screens/super_admin_shell.dart';
import 'app_session.dart';
import 'config.dart';
import 'customer/screens/customer_shell.dart';
import 'screens/gate_login_screen.dart';
import 'theme.dart';

class MusaitApp {
  static Future<void> start({required String sector}) async {
    WidgetsFlutterBinding.ensureInitialized();
    AppConfig.boot(sector: sector);
    await initializeDateFormatting('tr');
    final session = AppSession();
    await session.restore();
    runApp(MusaitRoot(session: session));
  }
}

class MusaitRoot extends StatelessWidget {
  const MusaitRoot({super.key, required this.session});
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        return MaterialApp(
          title: AppConfig.appTitle,
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(AppConfig.seedHex),
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: session.restoring
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : _home(session),
        );
      },
    );
  }
}

Widget _home(AppSession session) {
  final resetToken = Uri.base.queryParameters['reset'];
  if (resetToken != null && resetToken.isNotEmpty) {
    return ResetPasswordScreen(session: session, token: resetToken);
  }
  if (session.isBusiness) {
    return session.admin.user!.isSuperAdmin
        ? SuperAdminShell(session: session.admin)
        : AdminShell(session: session.admin);
  }
  if (session.isCustomer) {
    return CustomerShell(session: session.customer);
  }
  return GateLoginScreen(session: session);
}
