import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import '../../services/rider_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/helpers.dart';
import 'rider_deliveries_screen.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  int _currentIndex = 0;
  int _unreadCount = 0;
  final _notificationsKey = GlobalKey<_RiderNotificationsTabState>();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollUnread();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _pollUnread());
  }

  Future<void> _pollUnread() async {
    try {
      final res = await RiderService.getNotifications(unreadOnly: true);
      if (mounted) setState(() => _unreadCount = res.unreadCount);
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const RiderDeliveriesScreen(),
      _RiderNotificationsTab(key: _notificationsKey),
    ];

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) {
              setState(() => _currentIndex = i);
              if (i == 1) _notificationsKey.currentState?.reload();
            },
            backgroundColor: Colors.white,
            indicatorColor: AppTheme.primaryLight,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.delivery_dining_outlined),
                selectedIcon: Icon(Icons.delivery_dining_rounded, color: AppTheme.primary),
                label: 'Deliveries',
              ),
              NavigationDestination(
                icon: _unreadCount > 0
                    ? Badge(
                        label: Text('$_unreadCount', style: const TextStyle(fontSize: 10)),
                        child: const Icon(Icons.notifications_none_rounded),
                      )
                    : const Icon(Icons.notifications_none_rounded),
                selectedIcon: const Icon(Icons.notifications_rounded, color: AppTheme.primary),
                label: 'Alerts',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiderNotificationsTab extends StatefulWidget {
  const _RiderNotificationsTab({super.key});

  @override
  State<_RiderNotificationsTab> createState() => _RiderNotificationsTabState();
}

class _RiderNotificationsTabState extends State<_RiderNotificationsTab> {
  bool _loading = false;
  List<NotificationItem> _items = [];

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await RiderService.getNotifications();
      if (mounted) setState(() => _items = res.items);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No notifications'))
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final n = _items[i];
                    return ListTile(
                      title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w800)),
                      subtitle: Text(n.body),
                      trailing: Text(formatDateTime(n.createdAt), style: const TextStyle(fontSize: 11)),
                      onTap: () async {
                        if (!n.read) await RiderService.markNotificationRead(n.id);
                        _load();
                      },
                    );
                  },
                ),
    );
  }
}
