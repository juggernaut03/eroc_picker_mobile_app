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
