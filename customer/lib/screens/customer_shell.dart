import 'package:flutter/material.dart';

import '../session.dart';
import 'business_list_screen.dart';
import 'my_requests_screen.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key, required this.session});
  final CustomerSession session;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      BusinessListScreen(session: widget.session),
      MyRequestsScreen(session: widget.session),
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.storefront_outlined), label: 'İşletmem'),
          NavigationDestination(icon: Icon(Icons.event_available_outlined), label: 'Kayıtlarım'),
        ],
      ),
    );
  }
}
