import 'package:flutter/material.dart';

import '../models/session.dart';
import '../theme.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.session});

  final SessionController session;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  var _loading = false;
  var _sent = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.session.api.forgotPassword(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Şifremi unuttum')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          if (_sent) ...[
            const Text(
              'E-posta kayıtlıysa sıfırlama bağlantısı gönderildi. Gelen kutunuzu kontrol edin.',
              style: TextStyle(fontSize: 16, height: 1.45),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Girişe dön')),
          ] else ...[
            const Text(
              'SaaS yönetim hesabınızın e-postasını yazın. Bağlantı 2 saat geçerlidir.',
              style: TextStyle(color: muted, height: 1.45),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'E-posta'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? 'Gönderiliyor...' : 'Bağlantı gönder'),
            ),
          ],
        ],
      ),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.session, required this.token});

  final SessionController session;
  final String token;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (_password.text.length < 6) {
      setState(() => _error = 'Şifre en az 6 karakter olmalı.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Şifreler eşleşmiyor.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.session.api.resetPassword(widget.token, _password.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen(session: widget.session)),
        (_) => false,
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni şifre')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          const Text('Yönetim hesabınız için yeni bir şifre belirleyin.', style: TextStyle(color: muted)),
          const SizedBox(height: 20),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Yeni şifre'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            obscureText: true,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'Şifre tekrar'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: Text(_loading ? 'Kaydediliyor...' : 'Şifreyi güncelle'),
          ),
        ],
      ),
    );
  }
}
