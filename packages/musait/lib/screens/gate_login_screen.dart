import 'package:flutter/material.dart';

import '../admin/screens/forgot_password_screen.dart';
import '../app_session.dart';
import '../config.dart';
import '../theme.dart';

class GateLoginScreen extends StatefulWidget {
  const GateLoginScreen({super.key, required this.session});
  final AppSession session;

  @override
  State<GateLoginScreen> createState() => _GateLoginScreenState();
}

class _GateLoginScreenState extends State<GateLoginScreen> {
  var _kind = LoginKind.business;
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email.text = AppConfig.managerDemoEmail;
  }

  void _select(LoginKind kind) {
    setState(() {
      _kind = kind;
      _error = null;
      _email.text = kind == LoginKind.business ? AppConfig.managerDemoEmail : AppConfig.customerDemoEmail;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.session.login(
        kind: _kind,
        email: _email.text.trim(),
        password: _password.text,
      );
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
            Text(AppConfig.appTitle, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 8),
            Text(
              'Aynı uygulamada işletme yönetimi ve müşteri randevusu. Yalnızca ${AppConfig.sectorLabel} sektörü.',
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 24),
            SegmentedButton<LoginKind>(
              segments: const [
                ButtonSegment(value: LoginKind.business, label: Text('İşletme'), icon: Icon(Icons.storefront_outlined)),
                ButtonSegment(value: LoginKind.customer, label: Text('Müşteri'), icon: Icon(Icons.person_outline)),
              ],
              selected: {_kind},
              onSelectionChanged: (value) => _select(value.first),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'E-posta'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Şifre'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? 'Giriş...' : 'Giriş yap'),
            ),
            if (_kind == LoginKind.business)
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ForgotPasswordScreen(session: widget.session.admin),
                    ),
                  );
                },
                child: const Text('Şifremi unuttum'),
              ),
            const SizedBox(height: 8),
            Text(
              _kind == LoginKind.business
                  ? 'İşletme hesabını süper yönetici oluşturur.'
                  : 'Müşteri hesabını ${AppConfig.sectorLabel} yöneticisi oluşturur. Kayıt açık değildir.',
              style: const TextStyle(color: muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
