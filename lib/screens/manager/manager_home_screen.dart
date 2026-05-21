import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import 'orders_tab.dart';
import 'pickers_tab.dart';
import 'notifications_tab.dart';
// import 'escalations_tab.dart';

class ManagerHomeScreen extends StatefulWidget {
  const ManagerHomeScreen({super.key});

  @override
  State<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> {
  int _currentIndex = 0;
  // final _escalationsKey = GlobalKey<EscalationsTabState>();
  final _notificationsKey = GlobalKey<NotificationsTabState>();

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
      if (entries[i].isNotifications) _notificationsKey.currentState?.reload();
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
                    icon: Icon(e.icon),
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
