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
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _Empty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: _items.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _NotificationCard(
                        item: _items[i],
                        onTap: () => _onTap(_items[i]),
                      ),
                    ),
                  ),
                ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.notifications_none_rounded, size: 44, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 20),
            const Text(
              'No notifications yet',
              style: TextStyle(color: Color(0xFF334155), fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "You'll see alerts here when orders are assigned to you.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15, height: 1.4),
              ),
            ),
          ],
        ),
      );
}

class _NotificationCard extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;
  const _NotificationCard({required this.item, required this.onTap});

  ({IconData icon, Color color}) get _style {
    switch (item.type) {
      case 'order_assigned':
        return (icon: Icons.assignment_ind_rounded, color: AppTheme.primary);
      case 'order_received':
        return (icon: Icons.shopping_bag_rounded, color: AppTheme.primary);
      case 'escalation':
        return (icon: Icons.report_problem_rounded, color: AppTheme.error);
      default:
        return (icon: Icons.notifications_rounded, color: AppTheme.primary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final hasOrder = item.metadata['orders_idorders'] != null;
    return Material(
      color: item.read ? Colors.white : style.color.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.read ? AppTheme.border : style.color.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(style.icon, color: style.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: item.read ? FontWeight.w600 : FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (!item.read)
                          Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.body,
                      style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.35),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 13, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          formatDateTime(item.createdAt),
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                        if (hasOrder) ...[
                          const Spacer(),
                          Icon(Icons.chevron_right_rounded, size: 16, color: style.color),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
