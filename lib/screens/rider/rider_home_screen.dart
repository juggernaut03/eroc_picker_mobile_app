import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import '../../models/order_model.dart';
import '../../services/rider_location_tracker.dart';
import '../../services/rider_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/helpers.dart';
import 'delivery_detail_screen.dart';
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
    RiderLocationTracker.stop();
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

  /// Pull the order id out of a notification's metadata. Backend stores it as
  /// `orders_idorders` (string); be tolerant of a couple of key/shape variants.
  int? _orderIdFrom(NotificationItem n) {
    final m = n.metadata;
    final raw = m['orders_idorders'] ?? m['order_id'] ?? m['ordersIdorders'];
    if (raw == null) return null;
    return int.tryParse(raw.toString());
  }

  Future<void> _openNotification(NotificationItem n) async {
    if (!n.read) {
      await RiderService.markNotificationRead(n.id);
      _load();
    }

    final orderId = _orderIdFrom(n);
    if (orderId == null) return; // non-order notification — just mark read

    // The detail screen needs a full assignment; the notification only carries
    // the order id. Fetch this rider's deliveries and match on it.
    if (!mounted) return;
    DeliveryAssignment? target;
    try {
      final deliveries = await RiderService.getMyDeliveries();
      for (final d in deliveries) {
        if (d.ordersIdorders == orderId) {
          target = d;
          break;
        }
      }
    } catch (_) {}

    if (!mounted) return;
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order #$orderId is no longer assigned to you.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveryDetailScreen(assignment: target!),
      ),
    );
    if (mounted) _load();
  }

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
                    final hasOrder = _orderIdFrom(n) != null;
                    return ListTile(
                      title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w800)),
                      subtitle: Text(n.body),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(formatDateTime(n.createdAt), style: const TextStyle(fontSize: 11)),
                          if (hasOrder) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
                          ],
                        ],
                      ),
                      onTap: () => _openNotification(n),
                    );
                  },
                ),
    );
  }
}
