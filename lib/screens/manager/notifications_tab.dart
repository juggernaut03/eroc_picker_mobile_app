import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import '../../services/manager_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/helpers.dart';
import 'order_detail_screen.dart';

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({super.key});

  @override
  State<NotificationsTab> createState() => NotificationsTabState();
}

class NotificationsTabState extends State<NotificationsTab> {
  bool _loading = false;
  List<NotificationItem> _items = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Public refresh so the parent can call when tab is selected.
  Future<void> reload() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ManagerService.getNotifications();
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _unreadCount = res.unreadCount;
      });
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

  Future<void> _markAll() async {
    if (_unreadCount == 0) return;
    try {
      await ManagerService.markAllNotificationsRead();
      if (!mounted) return;
      setState(() {
        _items = _items.map((n) => n.copyWith(read: true)).toList();
        _unreadCount = 0;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _markOne(NotificationItem n) async {
    if (n.read) return;
    try {
      await ManagerService.markNotificationRead(n.id);
      if (!mounted) return;
      setState(() {
        _items = _items.map((x) => x.id == n.id ? x.copyWith(read: true) : x).toList();
        _unreadCount = (_unreadCount - 1).clamp(0, 1 << 30);
      });
    } catch (_) {}
  }

  Future<void> _onTap(NotificationItem n) async {
    // Mark read first (fire-and-forget on errors).
    await _markOne(n);

    final orderId = int.tryParse(n.metadata['orders_idorders']?.toString() ?? '');
    if (orderId == null) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final loaderEntry = OverlayEntry(
      builder: (_) => Container(
        color: Colors.black.withValues(alpha: 0.25),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
    Overlay.of(context).insert(loaderEntry);
    try {
      final order = await ManagerService.getOrder(orderId);
      loaderEntry.remove();
      if (order == null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Order #$orderId not found'), backgroundColor: AppTheme.error),
        );
        return;
      }
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(order: order, onRefresh: _load),
        ),
      );
      if (mounted) _load();
    } catch (e) {
      loaderEntry.remove();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text(
                'Notifications',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(fontSize: 11, color: AppTheme.error, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            IconButton(
              onPressed: _markAll,
              tooltip: 'Mark all read',
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: const EdgeInsets.all(6),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.done_all_rounded, size: 20, color: AppTheme.primary),
            ),
          IconButton(
            onPressed: _load,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: const EdgeInsets.all(6),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.refresh_rounded, size: 20, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
