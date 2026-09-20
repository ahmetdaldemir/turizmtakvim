import 'package:flutter/material.dart';

import '../config.dart';
import '../session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});
  final CustomerSession session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _email;
  final _password = TextEditingController(text: 'Demo123!');
  var _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: AppConfig.demoEmail);
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.session.login(_email.text.trim(), _password.text);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            Text(
              AppConfig.appTitle,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text('Yöneticinizin eklediği ${AppConfig.sectorLabel} hesabıyla giriş yapın. Diğer sektörü göremezsiniz.'),
            const SizedBox(height: 28),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-posta'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Şifre'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? 'Giriş yapılıyor...' : 'Giriş yap'),
            ),
            const SizedBox(height: 16),
            Text('Kayıt açık değildir. Hesabı ${AppConfig.sectorLabel} yöneticisi oluşturur.'),
            const SizedBox(height: 12),
            Text('Demo: ${AppConfig.demoEmail} / Demo123!'),
          ],
        ),
      ),
    );
  }
}
