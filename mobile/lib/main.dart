import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'config.dart';
import 'models/session.dart';
import 'screens/admin_shell.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/login_screen.dart';
import 'screens/super_admin_shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr');
  final session = SessionController();
  await session.restore();
  runApp(AdminApp(session: session));
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key, required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final color = session.vertical?.primaryColor ?? (AppConfig.isKuafor ? '#BE185D' : '#0F766E');
        return MaterialApp(
          title: AppConfig.appTitle,
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(color),
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: session.restoring
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : _homeFor(session),
        );
      },
    );
  }
}

Widget _homeFor(SessionController session) {
  final resetToken = Uri.base.queryParameters['reset'];
  if (resetToken != null && resetToken.isNotEmpty) {
    return ResetPasswordScreen(session: session, token: resetToken);
  }
  if (session.isLoggedIn) {
    return session.user!.isSuperAdmin
        ? SuperAdminShell(session: session)
        : AdminShell(session: session);
  }
  return LoginScreen(session: session);
}
