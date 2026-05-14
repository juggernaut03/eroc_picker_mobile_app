import 'package:flutter/material.dart';
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

  late final List<Widget> _tabs = [
    const OrdersTab(),
    const PickersTab(),
    NotificationsTab(key: _notificationsKey),
    // EscalationsTab(key: _escalationsKey),
  ];

  void _onTabSelected(int i) {
    setState(() => _currentIndex = i);
    if (i == 2) _notificationsKey.currentState?.reload();
    // if (i == 3) _escalationsKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabSelected,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            height: 64,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            indicatorColor: AppTheme.primaryLight,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded, color: AppTheme.primary),
                label: 'Orders',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline_rounded),
                selectedIcon: Icon(Icons.people_rounded, color: AppTheme.primary),
                label: 'Pickers',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_none_rounded),
                selectedIcon: Icon(Icons.notifications_rounded, color: AppTheme.primary),
                label: 'Notifications',
              ),
              // NavigationDestination(
              //   icon: Icon(Icons.error_outline_rounded),
              //   selectedIcon: Icon(Icons.error_rounded, color: AppTheme.primary),
              //   label: 'Escalations',
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
