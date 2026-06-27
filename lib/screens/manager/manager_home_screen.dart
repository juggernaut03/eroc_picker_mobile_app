import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/manager_service.dart';
import '../../services/notification_service.dart';
import '../../utils/app_theme.dart';
import 'orders_tab.dart';
import 'pickers_tab.dart';
import 'riders_tab.dart';
import 'notifications_tab.dart';
// import 'escalations_tab.dart';

class ManagerHomeScreen extends StatefulWidget {
  const ManagerHomeScreen({super.key});

  @override
  State<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> {
  int _currentIndex = 0;
  int _unreadCount = 0;
  // final _escalationsKey = GlobalKey<EscalationsTabState>();
  final _notificationsKey = GlobalKey<NotificationsTabState>();
  StreamSubscription? _notifTapSub;
  StreamSubscription? _foregroundSub;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollUnread(); // initial badge count
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _pollUnread());

    _notifTapSub = NotificationService.onNotificationTap.listen((_) {
      if (!mounted) return;
      // Notifications is always the last tab — setting 99 gets clamped to it in build().
      setState(() => _currentIndex = 99);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notificationsKey.currentState?.reload();
      });
    });

    _foregroundSub = NotificationService.onForegroundMessage.listen((_) {
      if (!mounted) return;
      _pollUnread();
      _notificationsKey.currentState?.reload();
    });
  }

  Future<void> _pollUnread() async {
    try {
      final res = await ManagerService.getNotifications();
      if (mounted) setState(() => _unreadCount = res.unreadCount);
    } catch (_) {}
  }

  @override
  void dispose() {
    _notifTapSub?.cancel();
    _foregroundSub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.watch<AuthProvider>().uiConfig;
    bool cap(String key) => ui == null ? true : ui.can(key);

    // Build tabs + destinations from one capability-filtered list so the
    // selected index always maps to the right screen. Notifications is always
    // available.
    final entries = <_NavEntry>[
      if (cap('can_view_orders'))
        _NavEntry(
          tab: const OrdersTab(),
          icon: Icons.grid_view_outlined,
          selectedIcon: Icons.grid_view_rounded,
          label: 'Orders',
        ),
      if (cap('can_manage_pickers'))
        _NavEntry(
          tab: const PickersTab(),
          icon: Icons.people_outline_rounded,
          selectedIcon: Icons.people_rounded,
          label: 'Pickers',
        ),
      if (cap('can_view_riders'))
        _NavEntry(
          tab: const RidersTab(),
          icon: Icons.delivery_dining_outlined,
          selectedIcon: Icons.delivery_dining_rounded,
          label: 'Riders',
        ),
      _NavEntry(
        tab: NotificationsTab(key: _notificationsKey),
        icon: Icons.notifications_none_rounded,
        selectedIcon: Icons.notifications_rounded,
        label: 'Notifications',
        isNotifications: true,
      ),
      // if (cap('can_view_remarks'))
      //   _NavEntry(tab: EscalationsTab(key: _escalationsKey), ...),
    ];

    // Clamp index in case capabilities changed and shrank the list.
    final safeIndex = _currentIndex.clamp(0, entries.length - 1);

    void onTabSelected(int i) {
      setState(() => _currentIndex = i);
      if (entries[i].isNotifications) {
        _notificationsKey.currentState?.reload();
        setState(() => _unreadCount = 0);
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: IndexedStack(
        index: safeIndex,
        children: entries.map((e) => e.tab).toList(),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: onTabSelected,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            height: 64,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            indicatorColor: AppTheme.primaryLight,
            destinations: entries
                .map(
                  (e) => NavigationDestination(
                    icon: e.isNotifications && _unreadCount > 0
                        ? Badge(
                            label: Text('$_unreadCount', style: const TextStyle(fontSize: 10)),
                            backgroundColor: AppTheme.error,
                            child: Icon(e.icon),
                          )
                        : Icon(e.icon),
                    selectedIcon: Icon(e.selectedIcon, color: AppTheme.primary),
                    label: e.label,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _NavEntry {
  final Widget tab;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isNotifications;

  _NavEntry({
    required this.tab,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.isNotifications = false,
  });
}
