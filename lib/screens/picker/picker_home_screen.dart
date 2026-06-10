import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../services/picker_service.dart';
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
  int _unreadCount = 0;
  final _notificationsKey = GlobalKey<PickerNotificationsScreenState>();
  StreamSubscription? _notifTapSub;
  StreamSubscription? _foregroundSub;
  Timer? _pollTimer;

  late final List<Widget> _tabs = [
    const PickerOrdersScreen(),
    PickerNotificationsScreen(key: _notificationsKey),
  ];

  @override
  void initState() {
    super.initState();
    _pollUnread(); // initial badge count
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _pollUnread());

    _notifTapSub = NotificationService.onNotificationTap.listen((_) {
      if (mounted) _onTabSelected(1);
    });

    _foregroundSub = NotificationService.onForegroundMessage.listen((_) {
      if (!mounted) return;
      _pollUnread();
      _notificationsKey.currentState?.reload();
    });
  }

  Future<void> _pollUnread() async {
    try {
      final res = await PickerService.getNotifications();
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

  void _onTabSelected(int i) {
    setState(() => _currentIndex = i);
    if (i == 1) {
      _notificationsKey.currentState?.reload();
      setState(() => _unreadCount = 0);
    }
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
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment_rounded, color: AppTheme.primary),
                label: 'Orders',
              ),
              NavigationDestination(
                icon: _unreadCount > 0
                    ? Badge(
                        label: Text('$_unreadCount', style: const TextStyle(fontSize: 10)),
                        backgroundColor: AppTheme.error,
                        child: const Icon(Icons.notifications_none_rounded),
                      )
                    : const Icon(Icons.notifications_none_rounded),
                selectedIcon: const Icon(Icons.notifications_rounded, color: AppTheme.primary),
                label: 'Notifications',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
