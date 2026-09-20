import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/customer_shell.dart';
import 'screens/login_screen.dart';
import 'session.dart';
import 'config.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr');
  final session = CustomerSession();
  await session.restore();
  runApp(CustomerApp(session: session));
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key, required this.session});
  final CustomerSession session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        return MaterialApp(
          title: AppConfig.appTitle,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(AppConfig.seedColor),
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: session.restoring
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : session.isLoggedIn
              ? CustomerShell(session: session)
              : LoginScreen(session: session),
        );
      },
    );
  }
}
