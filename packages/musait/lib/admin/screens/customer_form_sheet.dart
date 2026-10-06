import 'package:flutter/material.dart';

import '../models/models.dart';
import '../models/session.dart';
import 'package:musait/theme.dart';

class AddCustomerSheet extends StatefulWidget {
  const AddCustomerSheet({super.key, required this.session, this.customer});

  final SessionController session;
  final ManagedCustomer? customer;

  @override
  State<AddCustomerSheet> createState() => _AddCustomerSheetState();
}

class _AddCustomerSheetState extends State<AddCustomerSheet> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  final _password = TextEditingController();
  var _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _name = TextEditingController(text: customer?.name ?? '');
    _email = TextEditingController(text: customer?.email ?? '');
    _phone = TextEditingController(text: customer?.phone ?? '');
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.customer == null) {
        await widget.session.api.createCustomer(
          name: _name.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          password: _password.text,
        );
      } else {
        await widget.session.api.updateCustomer(
          id: widget.customer!.id,
          name: _name.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          password: _password.text,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.customer == null ? 'Müşteri ekle' : 'Müşteri bilgileri', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Ad')),
          const SizedBox(height: 10),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-posta')),
          const SizedBox(height: 10),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefon')),
          const SizedBox(height: 10),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(labelText: widget.customer == null ? 'Şifre' : 'Yeni şifre (isteğe bağlı)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 14),
          FilledButton(onPressed: _loading ? null : _submit, child: Text(_loading ? 'Kaydediliyor...' : 'Kaydet')),
        ],
      ),
    );
  }
}
