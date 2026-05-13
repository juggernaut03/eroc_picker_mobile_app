import 'package:flutter/material.dart';
import '../../models/item_model.dart';
import '../../models/order_model.dart';
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
                                      canAct:
                                          _currentStatus == 'in_progress',
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
                                                  'in_progress',
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
