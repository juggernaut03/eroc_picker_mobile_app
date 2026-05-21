import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/item_model.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/picker_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/product_image.dart';
import '../../widgets/status_badge.dart';
import 'barcode_scanner_screen.dart';

class OrderItemsScreen extends StatefulWidget {
  final Assignment assignment;

  const OrderItemsScreen({super.key, required this.assignment});

  @override
  State<OrderItemsScreen> createState() => _OrderItemsScreenState();
}

enum _ItemFilter { pending, picked, issues }

class _OrderItemsScreenState extends State<OrderItemsScreen> {
  bool _loading = true;
  String? _assignmentId;
  List<OrderItem> _items = [];
  String _currentStatus = '';
  _ItemFilter _filter = _ItemFilter.pending;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.assignment.status;
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _items = [];
    });
    try {
      // Load all items in one shot — picking workflow needs the full list
      // available for filtering across Pending/Picked/Issues tabs.
      final res = await PickerService.getOrderItems(
        widget.assignment.ordersIdorders,
      );
      setState(() {
        _assignmentId = res['assignment_id'];
        _items = List<OrderItem>.from(res['items']);
        _currentStatus = res['status'] ?? widget.assignment.status;
        _loading = false;
        // Default tab: completed orders open on Picked, others on Pending.
        // If current tab is empty but another has items, switch automatically.
        if (_currentStatus == 'completed') {
          _filter = _ItemFilter.picked;
        }
        _filter = _bestFilter(_filter);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openScanner() async {
    final assignmentId = _assignmentId;
    if (assignmentId == null || assignmentId.isEmpty) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(
          assignmentId: assignmentId,
          items: _items,
        ),
        fullscreenDialog: true,
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _startPicking() async {
    try {
      await PickerService.startPicking(widget.assignment.ordersIdorders);
      setState(() => _currentStatus = 'in_progress');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Picking started!'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _completeOrder() async {
    final pending = _items.where((i) => i.pickerStatus == null || i.pickerStatus!.isPending).toList();
    if (pending.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 22),
              SizedBox(width: 8),
              Text('Incomplete Items', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Text('${pending.length} item(s) not yet actioned. Complete anyway?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Complete')),
          ],
        ),
      );
      if (confirm != true) return;
    }
    try {
      await PickerService.completeOrder(widget.assignment.ordersIdorders);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order completed!'), backgroundColor: AppTheme.success),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _rejectOrder() async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 8),
            Text('Reject Order', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'e.g. injured hand, need reassignment',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await PickerService.rejectOrder(widget.assignment.ordersIdorders, reasonCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order rejected'), backgroundColor: AppTheme.warning),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  // Fully picked = status 'picked' AND quantity met
  int get _pickedCount => _pickedItems.length;
  int get _actionedCount => _items.where((i) => i.pickerStatus != null && !i.pickerStatus!.isPending).length;

  List<OrderItem> get _pendingItems => _items.where((i) {
        final ps = i.pickerStatus;
        return ps == null || ps.isPending;
      }).toList();

  List<OrderItem> get _pickedItems => _items.where((i) {
        final ps = i.pickerStatus;
        return ps != null && ps.isPicked && ps.pickedQuantity >= i.orderedQuantity;
      }).toList();

  // Issues = full failures (not_available/expired/damaged) + partial picks
  // (picked but qty < ordered).
  List<OrderItem> get _issueItems => _items.where((i) {
        final ps = i.pickerStatus;
        if (ps == null || ps.isPending) return false;
        if (ps.isPicked) return ps.pickedQuantity < i.orderedQuantity;
        return true;
      }).toList();

  List<OrderItem> _itemsFor(_ItemFilter f) {
    switch (f) {
      case _ItemFilter.pending: return _pendingItems;
      case _ItemFilter.picked: return _pickedItems;
      case _ItemFilter.issues: return _issueItems;
    }
  }

  // Pick the best available tab: keep current if it has items, otherwise
  // fall back to the first non-empty in order pending → picked → issues.
  _ItemFilter _bestFilter(_ItemFilter preferred) {
    if (_itemsFor(preferred).isNotEmpty) return preferred;
    for (final f in _ItemFilter.values) {
      if (_itemsFor(f).isNotEmpty) return f;
    }
    return preferred;
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.length;
    final progress = total > 0 ? _actionedCount / total : 0.0;
    final filtered = _itemsFor(_filter);
    // Capability gating for picker actions.
    final ui = context.watch<AuthProvider>().uiConfig;
    bool cap(String key) => ui == null ? true : ui.can(key);
    final canPickItems = cap('can_pick_items');
    // Map filtered index back to absolute index in _items so the index badge
    // ("1", "2", "3" …) stays consistent across tab switches.
    final absoluteIndexOf = {
      for (int i = 0; i < _items.length; i++) _items[i]: i + 1,
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF4F3FA),
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────
          _ItemsHeader(
            orderId: widget.assignment.ordersIdorders,
            status: _currentStatus,
            total: total,
            actioned: _actionedCount,
            picked: _pickedCount,
            progress: progress,
            loading: _loading,
            onRefresh: _load,
            onScan: (_currentStatus == 'in_progress' &&
                    (_assignmentId?.isNotEmpty ?? false) &&
                    _items.isNotEmpty)
                ? _openScanner
                : null,
          ),

          // ── Filter tabs ──────────────────────────────────────────
          if (!_loading && _items.isNotEmpty)
            _FilterTabs(
              selected: _filter,
              pendingCount: _pendingItems.length,
              pickedCount: _pickedItems.length,
              issuesCount: _issueItems.length,
              onSelect: (f) => setState(() => _filter = f),
            ),

          // ── Items ─────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
                : _items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                              child: const Icon(Icons.inventory_2_outlined, size: 36, color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 14),
                            const Text('No items found', style: TextStyle(color: Color(0xFF64748B), fontSize: 15)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: const Color(0xFF1565C0),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final columns = Responsive.columnsFor(width);
                            final maxContent =
                                Responsive.maxContentWidth(width);

                            if (filtered.isEmpty) {
                              return _EmptyFilter(filter: _filter);
                            }

                            if (columns == 1) {
                              return ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                    16, 8, 16, 130),
                                itemCount: filtered.length,
                                itemBuilder: (ctx, i) {
                                  final item = filtered[i];
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 14),
                                    child: _ItemCard(
                                      item: item,
                                      assignmentId: _assignmentId ?? '',
                                      canAct: _currentStatus == 'in_progress' &&
                                          canPickItems,
                                      onUpdated: _load,
                                      index: absoluteIndexOf[item] ?? (i + 1),
                                    ),
                                  );
                                },
                              );
                            }

                            return Center(
                              child: ConstrainedBox(
                                constraints:
                                    BoxConstraints(maxWidth: maxContent),
                                child: CustomScrollView(
                                  controller: _scrollController,
                                  slivers: [
                                    SliverPadding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 8, 16, 0),
                                      sliver: SliverGrid(
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: columns,
                                          mainAxisSpacing: 12,
                                          crossAxisSpacing: 12,
                                          mainAxisExtent: 200,
                                        ),
                                        delegate: SliverChildBuilderDelegate(
                                          (ctx, i) {
                                            final item = filtered[i];
                                            return _ItemCard(
                                              item: item,
                                              assignmentId:
                                                  _assignmentId ?? '',
                                              canAct: _currentStatus ==
                                                      'in_progress' &&
                                                  canPickItems,
                                              onUpdated: _load,
                                              index: absoluteIndexOf[item] ?? (i + 1),
                                            );
                                          },
                                          childCount: filtered.length,
                                        ),
                                      ),
                                    ),
                                    const SliverToBoxAdapter(
                                      child: SizedBox(height: 130),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        status: _currentStatus,
        pendingCount: _items.where((i) => i.pickerStatus == null || i.pickerStatus!.isPending).length,
        onStart: _startPicking,
        onComplete: _completeOrder,
        onReject: _rejectOrder,
        canStart: cap('can_start_picking'),
        canComplete: cap('can_complete_orders'),
        canReject: cap('can_reject_orders'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Items header — compact gradient + progress
// ─────────────────────────────────────────────────────────────────────────────
class _ItemsHeader extends StatelessWidget {
  final int orderId, total, actioned, picked;
  final String status;
  final double progress;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback? onScan;

  const _ItemsHeader({
    required this.orderId,
    required this.status,
    required this.total,
    required this.actioned,
    required this.picked,
    required this.progress,
    required this.loading,
    required this.onRefresh,
    this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final issues = actioned - picked;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F4C81), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // App bar row
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order #$orderId',
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                        Text('Picking list', style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 15)),
                      ],
                    ),
                  ),
                  StatusBadge(status),
                  if (onScan != null)
                    IconButton(
                      tooltip: 'Scan barcode',
                      icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24),
                      onPressed: onScan,
                    ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 24),
                    onPressed: onRefresh,
                  ),
                ],
              ),
            ),

            // Progress section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  // Stats row
                  Row(
                    children: [
                      _StatPill(value: '$actioned/$total', label: 'Actioned', color: Colors.white),
                      const SizedBox(width: 10),
                      _StatPill(value: '$picked', label: 'Picked', color: const Color(0xFF34D399)),
                      const SizedBox(width: 10),
                      _StatPill(value: '$issues', label: 'Issues', color: issues > 0 ? const Color(0xFFF87171) : Colors.white.withValues(alpha: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation(
                            progress == 1.0 ? const Color(0xFF34D399) : Colors.white,
                          ),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(progress * 100).round()}% complete',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatPill({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w900, height: 1)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter tabs — pending / picked / issues
// ─────────────────────────────────────────────────────────────────────────────
class _FilterTabs extends StatelessWidget {
  final _ItemFilter selected;
  final int pendingCount;
  final int pickedCount;
  final int issuesCount;
  final ValueChanged<_ItemFilter> onSelect;

  const _FilterTabs({
    required this.selected,
    required this.pendingCount,
    required this.pickedCount,
    required this.issuesCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: _FilterTab(
              label: 'Pending',
              count: pendingCount,
              accent: const Color(0xFF1565C0),
              isSelected: selected == _ItemFilter.pending,
              onTap: () => onSelect(_ItemFilter.pending),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterTab(
              label: 'Picked',
              count: pickedCount,
              accent: const Color(0xFF16A34A),
              isSelected: selected == _ItemFilter.picked,
              onTap: () => onSelect(_ItemFilter.picked),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterTab(
              label: 'Issues',
              count: issuesCount,
              accent: const Color(0xFFDC2626),
              isSelected: selected == _ItemFilter.issues,
              onTap: () => onSelect(_ItemFilter.issues),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final int count;
  final Color accent;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.count,
    required this.accent,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? accent : const Color(0xFFF4F3FA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFilter extends StatelessWidget {
  final _ItemFilter filter;
  const _EmptyFilter({required this.filter});

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (filter) {
      _ItemFilter.pending => (
          Icons.check_circle_outline_rounded,
          'All items actioned',
          'Switch tabs to review picked or issues.',
        ),
      _ItemFilter.picked => (
          Icons.shopping_basket_outlined,
          'Nothing picked yet',
          'Picked items will show up here.',
        ),
      _ItemFilter.issues => (
          Icons.thumb_up_alt_outlined,
          'No issues',
          'Items flagged as N/A, expired, damaged, or partial will appear here.',
        ),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 36, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Item card
// ─────────────────────────────────────────────────────────────────────────────
class _ItemCard extends StatelessWidget {
  final OrderItem item;
  final String assignmentId;
  final bool canAct;
  final VoidCallback onUpdated;
  final int index;

  const _ItemCard({
    required this.item,
    required this.assignmentId,
    required this.canAct,
    required this.onUpdated,
    required this.index,
  });

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemActionSheet(
        item: item,
        assignmentId: assignmentId,
        onDone: () {
          Navigator.pop(context);
          onUpdated();
        },
      ),
    );
  }

  Color _statusAccent(String s) {
    switch (s) {
      case 'picked': return const Color(0xFF16A34A);
      case 'not_available': return const Color(0xFFDC2626);
      case 'expired': return const Color(0xFFD97706);
      case 'damaged': return const Color(0xFFBE185D);
      default: return const Color(0xFF94A3B8);
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'picked': return Icons.check_circle_rounded;
      case 'not_available': return Icons.remove_circle_rounded;
      case 'expired': return Icons.access_time_rounded;
      case 'damaged': return Icons.broken_image_rounded;
      default: return Icons.radio_button_unchecked_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ps = item.pickerStatus;
    // Treat "picked but qty == 0" as a failed pick — defensive against any
    // legacy rows that may have landed before the save logic was fixed.
    final rawStatus = ps?.pickedStatus ?? 'pending';
    final statusStr =
        (rawStatus == 'picked' && (ps?.pickedQuantity ?? 0) == 0) ? 'not_available' : rawStatus;
    final accent = _statusAccent(statusStr);
    final isDone = statusStr != 'pending';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: canAct ? () => _showActionSheet(context) : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
            ],
            border: isDone ? Border.all(color: accent.withValues(alpha: 0.25)) : null,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product image / status icon
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                child: SizedBox(
                  width: 90,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ProductImage(
                        url: item.pcodeImg,
                        width: 90,
                        height: 90,
                        fallback: _ImageFallback(accent: accent, statusStr: statusStr, index: index, statusIcon: _statusIcon(statusStr)),
                      ),
                      // Status overlay
                      if (isDone)
                        Positioned(
                          top: 6, right: 6,
                          child: Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 4)],
                            ),
                            child: Icon(_statusIcon(statusStr), color: Colors.white, size: 14),
                          ),
                        ),
                      // Index badge
                      Positioned(
                        bottom: 6, left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('$index', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: item.itemName ?? 'Item'),
                                  if (item.pCode != null && item.pCode!.isNotEmpty)
                                    TextSpan(text: ' (${item.pCode})'),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDone ? const Color(0xFF334155) : const Color(0xFF0F172A),
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Builder(builder: (_) {
                            final isPartial = statusStr == 'picked' &&
                                ps != null &&
                                ps.pickedQuantity < item.orderedQuantity;
                            return _ItemStatusChip(
                              statusStr,
                              labelOverride: isPartial ? 'Partial' : null,
                              colorOverride: isPartial ? const Color(0xFFD97706) : null,
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Pack size + price row
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (item.packSize != null)
                            _MetaBadge(item.packSize!, color: const Color(0xFF64748B)),
                          if (item.productOfferPrice != null)
                            _MetaBadge('₹${item.productOfferPrice!.toStringAsFixed(0)}', color: const Color(0xFF1565C0)),
                        ],
                      ),
                      if (item.barcode != null) ...[
                        const SizedBox(height: 3),
                        Text(item.barcode!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1), fontFamily: 'monospace')),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _QtyBadge(label: 'Quantity', value: item.orderedQuantity, color: const Color(0xFF64748B)),
                          if (ps != null && ps.pickedQuantity > 0)
                            _QtyBadge(label: 'Got', value: ps.pickedQuantity, color: const Color(0xFF16A34A)),
                        ],
                      ),
                      if (ps?.remark != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.format_quote_rounded, size: 16, color: Color(0xFFD97706)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  ps!.remark!,
                                  style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Color(0xFF92400E)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              if (canAct)
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: isDone ? accent.withValues(alpha: 0.1) : const Color(0xFFF4F3FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isDone ? Icons.edit_rounded : Icons.chevron_right_rounded,
                      size: 22,
                      color: isDone ? accent : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _ItemStatusChip extends StatelessWidget {
  final String status;
  final String? labelOverride;
  final Color? colorOverride;
  const _ItemStatusChip(this.status, {this.labelOverride, this.colorOverride});

  @override
  Widget build(BuildContext context) {
    final color = colorOverride ?? AppTheme.itemStatusColor(status);
    final label = labelOverride ?? AppTheme.itemStatusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
    );
  }
}

class _QtyBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _QtyBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$label: $value', style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w700)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom action bar
// ─────────────────────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final String status;
  final int pendingCount;
  final VoidCallback onStart, onComplete, onReject;
  final bool canStart, canComplete, canReject;

  const _BottomBar({
    required this.status,
    required this.pendingCount,
    required this.onStart,
    required this.onComplete,
    required this.onReject,
    this.canStart = true,
    this.canComplete = true,
    this.canReject = true,
  });

  @override
  Widget build(BuildContext context) {
    if (status != 'assigned' && status != 'in_progress') return const SizedBox.shrink();

    // The primary action for this status (start while assigned, complete while
    // in_progress). If the picker lacks that capability AND can't reject, the
    // bar has nothing to show.
    final primaryAllowed = status == 'assigned' ? canStart : canComplete;
    if (!primaryAllowed && !canReject) return const SizedBox.shrink();

    final allActioned = pendingCount == 0;

    return Container(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status == 'in_progress' && !allActioned) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$pendingCount item${pendingCount == 1 ? '' : 's'} still pending — action all items to complete',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  // Reject button — compact outlined
                  if (canReject) ...[
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFF87171).withValues(alpha: 0.5)),
                        color: const Color(0xFFFEF2F2),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 22),
                        onPressed: onReject,
                        tooltip: 'Reject order',
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Primary action
                  if (primaryAllowed)
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: status == 'assigned'
                            ? ElevatedButton.icon(
                                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                                label: const Text('Start Picking'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1565C0),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                ),
                                onPressed: onStart,
                              )
                            : ElevatedButton.icon(
                                icon: const Icon(Icons.check_rounded, size: 20),
                                label: const Text('Complete Order'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  disabledBackgroundColor: const Color(0xFFE5E7EB),
                                  disabledForegroundColor: const Color(0xFF9CA3AF),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                ),
                                onPressed: allActioned ? onComplete : null,
                              ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Item action bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _ItemActionSheet extends StatefulWidget {
  final OrderItem item;
  final String assignmentId;
  final VoidCallback onDone;

  const _ItemActionSheet({required this.item, required this.assignmentId, required this.onDone});

  @override
  State<_ItemActionSheet> createState() => _ItemActionSheetState();
}

class _ItemActionSheetState extends State<_ItemActionSheet> {
  late int _qty;
  // Per-issue-type quantities for the unpicked units
  final Map<String, int> _issueQty = {'not_available': 0, 'expired': 0, 'damaged': 0};
  final _remarkCtrl = TextEditingController();
  bool _loading = false;

  // Issue types for the unpicked units
  final _issueTypes = [
    ('not_available', 'Not Available', Icons.remove_circle_rounded, Color(0xFFDC2626)),
    ('expired', 'Expired', Icons.access_time_rounded, Color(0xFFD97706)),
    ('damaged', 'Damaged', Icons.broken_image_rounded, Color(0xFFBE185D)),
  ];

  static const _labelToType = {
    'Not Available': 'not_available',
    'Expired': 'expired',
    'Damaged': 'damaged',
  };

  int get _missing => widget.item.orderedQuantity - _qty;
  int get _allocated => _issueQty.values.fold(0, (a, b) => a + b);
  int get _unallocated => _missing - _allocated;

  @override
  void initState() {
    super.initState();
    final max = widget.item.orderedQuantity;
    final cur = widget.item.pickerStatus;
    if (cur != null) {
      if (cur.pickedStatus == 'picked') {
        _qty = cur.pickedQuantity.clamp(0, max);
      } else if (cur.pickedStatus == 'pending') {
        _qty = max;
      } else {
        // Full issue (legacy single-reason save)
        _qty = 0;
        if (_issueQty.containsKey(cur.pickedStatus)) {
          _issueQty[cur.pickedStatus] = max;
        }
      }
      _parseRemark(cur.remark ?? '');
      // Auto-fill unallocated shortfall to the first issue type so the form is valid
      if (_qty < max && _allocated == 0) {
        _issueQty['not_available'] = max - _qty;
      }
    } else {
      _qty = max;
    }
  }

  // Parse remarks of form: "Not Available: 1 unit, Damaged: 2 units — picker notes"
  // or single-reason: "Expired: 3 units — notes"
  void _parseRemark(String raw) {
    if (raw.isEmpty) return;

    String breakdown = raw;
    String notes = '';
    final emIdx = raw.indexOf(' — ');
    if (emIdx >= 0) {
      breakdown = raw.substring(0, emIdx);
      notes = raw.substring(emIdx + 3).trim();
    }

    final entryRe = RegExp(r'(Not Available|Expired|Damaged):\s*(\d+)\s*unit');
    final matches = entryRe.allMatches(breakdown).toList();
    if (matches.isEmpty) {
      // No structured breakdown — treat the whole thing as the picker's note
      _remarkCtrl.text = raw;
      return;
    }
    for (final m in matches) {
      final type = _labelToType[m.group(1)!];
      final n = int.tryParse(m.group(2)!);
      if (type != null && n != null) _issueQty[type] = n;
    }
    _remarkCtrl.text = notes;
  }

  @override
  void dispose() {
    _remarkCtrl.dispose();
    super.dispose();
  }

  String _issueLabel(String type) =>
      _issueTypes.firstWhere((t) => t.$1 == type).$2;

  void _changeQty(int delta) {
    final max = widget.item.orderedQuantity;
    final next = (_qty + delta).clamp(0, max);
    setState(() {
      _qty = next;
      // Shortfall shrunk — trim allocations from the highest types down
      var over = _allocated - _missing;
      if (over > 0) {
        for (final t in _issueTypes.reversed) {
          if (over <= 0) break;
          final q = _issueQty[t.$1] ?? 0;
          if (q <= 0) continue;
          final take = q < over ? q : over;
          _issueQty[t.$1] = q - take;
          over -= take;
        }
      }
    });
  }

  void _bumpIssue(String type, int delta) {
    final next = (_issueQty[type] ?? 0) + delta;
    if (next < 0) return;
    if (delta > 0 && _unallocated <= 0) return;
    setState(() => _issueQty[type] = next);
  }

  String _buildBreakdown() {
    final parts = <String>[];
    for (final t in _issueTypes) {
      final q = _issueQty[t.$1] ?? 0;
      if (q > 0) parts.add('${t.$2}: $q unit${q == 1 ? '' : 's'}');
    }
    return parts.join(', ');
  }

  Future<void> _save() async {
    final max = widget.item.orderedQuantity;
    final notes = _remarkCtrl.text.trim();

    String status;
    int savedQty;
    String? savedRemark;

    if (_qty >= max) {
      // Full pick — no shortfall, ignore any issue allocations
      status = 'picked';
      savedQty = max;
      savedRemark = notes.isEmpty ? null : notes;
    } else {
      // Must allocate every missing unit to a reason
      if (_unallocated != 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_unallocated > 0
                ? '$_unallocated unit${_unallocated == 1 ? '' : 's'} still need a reason'
                : 'Issue quantities exceed the shortfall'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
      final breakdown = _buildBreakdown();
      savedRemark = notes.isEmpty ? breakdown : '$breakdown — $notes';

      if (_qty == 0) {
        // Nothing picked — surface as a real failure status (N/A / Expired /
        // Damaged) so the card never shows a green "Picked" badge for 0 units.
        // Use the largest-count reason; the full per-reason breakdown stays in
        // the remark.
        final usedTypes = _issueQty.entries.where((e) => e.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        status = usedTypes.isNotEmpty ? usedTypes.first.key : 'not_available';
        savedQty = 0;
      } else {
        // Partial pick — at least one unit picked, rest are issues.
        status = 'picked';
        savedQty = _qty;
      }
    }

    setState(() => _loading = true);
    try {
      await PickerService.updateItemStatus(
        assignmentId: widget.assignmentId,
        orderItemId: widget.item.id,
        pickedStatus: status,
        pickedQuantity: savedQty,
        remark: savedRemark,
      );
      widget.onDone();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.item.orderedQuantity;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 4),

          // Scrollable body
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Product image + close button row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ProductImage(
                          url: widget.item.pcodeImg,
                          width: 80,
                          height: 80,
                          fallback: Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F3FA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.inventory_2_outlined, size: 32, color: Color(0xFFCBD5E1)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Item name + meta
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: widget.item.itemName ?? 'Item'),
                                  if (widget.item.pCode != null && widget.item.pCode!.isNotEmpty)
                                    TextSpan(text: ' (${widget.item.pCode})'),
                                ],
                              ),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            if (widget.item.barcode != null)
                              Text(widget.item.barcode!,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontFamily: 'monospace')),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4F3FA),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text('Ordered: $max',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                ),
                                if (widget.item.packSize != null)
                                  _MetaBadge(widget.item.packSize!, color: const Color(0xFF64748B)),
                                if (widget.item.productOfferPrice != null)
                                  _MetaBadge('₹${widget.item.productOfferPrice!.toStringAsFixed(0)}', color: const Color(0xFF1565C0)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Quantity picker — full range 0..max
                  const Text('Picked Quantity',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F3FA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        _QtyButton(
                          icon: Icons.remove_rounded,
                          enabled: _qty > 0,
                          onTap: () => _changeQty(-1),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '$_qty',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                              ),
                              Text(
                                'of $max',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        _QtyButton(
                          icon: Icons.add_rounded,
                          enabled: _qty < max,
                          onTap: () => _changeQty(1),
                        ),
                      ],
                    ),
                  ),

                  // Issue breakdown for the missing units (shown when partial / nothing picked)
                  if (_qty < max) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _unallocated > 0
                                ? '$_unallocated of ${max - _qty} unit${(max - _qty) == 1 ? '' : 's'} need a reason'
                                : 'All ${max - _qty} unit${(max - _qty) == 1 ? '' : 's'} have a reason',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _unallocated > 0 ? const Color(0xFF92400E) : const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Column(
                      children: _issueTypes.map((t) {
                        final (value, label, icon, color) = t;
                        final q = _issueQty[value] ?? 0;
                        final active = q > 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                          decoration: BoxDecoration(
                            color: active ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: active ? color.withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
                              width: active ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(icon, size: 20, color: active ? color : const Color(0xFF94A3B8)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: active ? color : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              _IssueStepper(
                                value: q,
                                color: color,
                                onMinus: q > 0 ? () => _bumpIssue(value, -1) : null,
                                onPlus: _unallocated > 0 ? () => _bumpIssue(value, 1) : null,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Remark — required when there's an issue, optional otherwise
                  Text(
                    _qty < max ? 'Remark for manager' : 'Remark (optional)',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _remarkCtrl,
                    decoration: InputDecoration(
                      hintText: _qty < max
                          ? 'Details about the issue (e.g. batch expired Jan, packaging torn)'
                          : 'e.g. Item on back shelf, different batch',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                        borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                        borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                        borderSide: BorderSide(color: Color(0xFF1565C0), width: 2),
                      ),
                    ),
                    maxLines: 2,
                  ),

                  const SizedBox(height: 20),

                  // Save
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Item'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Image fallback — shown when no image URL or image fails to load
// ─────────────────────────────────────────────────────────────────────────────
class _ImageFallback extends StatelessWidget {
  final Color accent;
  final String statusStr;
  final int index;
  final IconData statusIcon;

  const _ImageFallback({
    required this.accent,
    required this.statusStr,
    required this.index,
    required this.statusIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = statusStr != 'pending';
    return SizedBox(
      width: 72,
      child: Container(
        color: isDone ? accent.withValues(alpha: 0.08) : const Color(0xFFF4F3FA),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDone ? statusIcon : Icons.inventory_2_outlined,
              size: 26,
              color: isDone ? accent : const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text('$index', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small metadata badge (pack size, price)
// ─────────────────────────────────────────────────────────────────────────────
class _MetaBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _MetaBadge(this.text, {required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Text(text, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w600)),
      );
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFF1565C0) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: enabled ? Colors.white : const Color(0xFF94A3B8), size: 22),
        ),
      );
}

class _IssueStepper extends StatelessWidget {
  final int value;
  final Color color;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  const _IssueStepper({required this.value, required this.color, this.onMinus, this.onPlus});

  Widget _btn(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: enabled ? color.withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: enabled ? color : const Color(0xFFCBD5E1)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove_rounded, onMinus),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: value > 0 ? color : const Color(0xFF94A3B8),
              ),
            ),
          ),
          _btn(Icons.add_rounded, onPlus),
        ],
      );
}
