import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../utils/app_theme.dart';
import 'picker_orders_screen.dart';
import 'picker_notifications_screen.dart';

class PickerHomeScreen extends StatefulWidget {
  const PickerHomeScreen({super.key});

  @override
  State<PickerHomeScreen> createState() => _PickerHomeScreenState();
}

class _PickerHomeScreenState extends State<PickerHomeScreen> {
  int _currentIndex = 0;
  final _notificationsKey = GlobalKey<PickerNotificationsScreenState>();
  StreamSubscription? _notifTapSub;

  late final List<Widget> _tabs = [
    const PickerOrdersScreen(),
    PickerNotificationsScreen(key: _notificationsKey),
  ];

  @override
  void initState() {
    super.initState();
    _notifTapSub = NotificationService.onNotificationTap.listen((_) {
      if (mounted) _onTabSelected(1);
    });
  }

  @override
  void dispose() {
    _notifTapSub?.cancel();
    super.dispose();
  }

  void _onTabSelected(int i) {
    setState(() => _currentIndex = i);
    if (i == 1) _notificationsKey.currentState?.reload();
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
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment_rounded, color: AppTheme.primary),
                label: 'Orders',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_none_rounded),
                selectedIcon: Icon(Icons.notifications_rounded, color: AppTheme.primary),
                label: 'Notifications',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
