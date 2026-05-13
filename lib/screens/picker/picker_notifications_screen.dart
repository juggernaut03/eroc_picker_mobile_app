import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import '../../services/picker_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/helpers.dart';
import 'order_items_screen.dart';

class PickerNotificationsScreen extends StatefulWidget {
  const PickerNotificationsScreen({super.key});

  @override
  State<PickerNotificationsScreen> createState() => PickerNotificationsScreenState();
}

class PickerNotificationsScreenState extends State<PickerNotificationsScreen> {
  bool _loading = false;
  List<NotificationItem> _items = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await PickerService.getNotifications();
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
      await PickerService.markAllNotificationsRead();
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

  Future<void> _onTap(NotificationItem n) async {
    if (!n.read) {
      try {
        await PickerService.markNotificationRead(n.id);
        if (mounted) {
          setState(() {
            _items = _items.map((x) => x.id == n.id ? x.copyWith(read: true) : x).toList();
            _unreadCount = (_unreadCount - 1).clamp(0, 1 << 30);
          });
        }
      } catch (_) {}
    }

    // If this notification is about an order assignment, open the order detail.
    final orderIdStr = n.metadata['orders_idorders']?.toString();
    final orderId = int.tryParse(orderIdStr ?? '');
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
      final assignment = await PickerService.findAssignmentByOrderId(orderId);
      loaderEntry.remove();
      if (assignment == null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Order #$orderId not found'), backgroundColor: AppTheme.error),
        );
        return;
      }
      await navigator.push(
        MaterialPageRoute(builder: (_) => OrderItemsScreen(assignment: assignment)),
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
