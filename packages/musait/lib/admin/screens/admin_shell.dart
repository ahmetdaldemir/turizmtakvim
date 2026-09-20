import 'package:flutter/material.dart';

import '../models/session.dart';
import 'package:musait/theme.dart';
import 'customers_screen.dart';
import 'gallery_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'requests_screen.dart';
import 'resources_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.session});

  final SessionController session;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  var _index = 0;
  var _unread = 0;

  @override
  void initState() {
    super.initState();
    _refreshBadge();
  }

  Future<void> _refreshBadge() async {
    try {
      final count = await widget.session.api.unreadCount();
      if (mounted) setState(() => _unread = count);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final resourceLabel = widget.session.vertical?.resourceLabel ?? 'Liste';
    final isKuafor = widget.session.vertical?.key == 'kuafor';
    final pages = [
      HomeScreen(
        session: widget.session,
        onChanged: _refreshBadge,
        onOpenRequests: () => setState(() => _index = 1),
      ),
      RequestsScreen(session: widget.session, onChanged: _refreshBadge),
      ResourcesScreen(session: widget.session),
      if (isKuafor) GalleryScreen(session: widget.session),
      CustomersScreen(session: widget.session),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) {
          setState(() => _index = index);
          _refreshBadge();
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: 'Takvim'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _unread > 0,
              label: Text('$_unread'),
              backgroundColor: const Color(0xFFD97706),
              child: const Icon(Icons.inbox_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: _unread > 0,
              label: Text('$_unread'),
              backgroundColor: const Color(0xFFD97706),
              child: const Icon(Icons.inbox),
            ),
            label: 'Talepler',
          ),
          NavigationDestination(
            icon: Icon(isKuafor ? Icons.content_cut : Icons.home_outlined),
            selectedIcon: Icon(isKuafor ? Icons.content_cut : Icons.home),
            label: resourceLabel,
          ),
          if (isKuafor)
            const NavigationDestination(
              icon: Icon(Icons.photo_library_outlined),
              selectedIcon: Icon(Icons.photo_library),
              label: 'Galeri',
            ),
          const NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Müşteri'),
        ],
      ),
    );
  }
}

class PanelHeader extends StatelessWidget {
  const PanelHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.session,
    this.onRefresh,
    this.onLogout,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final SessionController? session;
  final VoidCallback? onRefresh;
  final VoidCallback? onLogout;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink),
                ),
                if ((subtitle ?? '').isNotEmpty)
                  Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted)),
              ],
            ),
          ),
          ...actions,
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'profile' && session != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ProfileScreen(session: session!)),
                );
              }
              if (value == 'refresh') onRefresh?.call();
              if (value == 'logout') onLogout?.call();
            },
            itemBuilder: (context) => [
              if (session != null) const PopupMenuItem(value: 'profile', child: Text('Profil')),
              if (onRefresh != null) const PopupMenuItem(value: 'refresh', child: Text('Yenile')),
              if (onLogout != null) const PopupMenuItem(value: 'logout', child: Text('Çıkış')),
            ],
          ),
        ],
      ),
    );
  }
}
