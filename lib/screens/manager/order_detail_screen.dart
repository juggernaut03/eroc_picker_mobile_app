import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/item_model.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/manager_service.dart';
import '../../services/super_admin_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/helpers.dart';
import '../../utils/order_pdf.dart';
import '../../utils/responsive.dart';
import '../../widgets/product_image.dart';
import '../../widgets/status_badge.dart';

class OrderDetailScreen extends StatefulWidget {
  final Order order;
  final VoidCallback onRefresh;
  final Escalation? highlightEscalation;
  /// When true the screen is shown to the super admin: no action buttons,
  /// items fetched via the super-admin endpoint.
  final bool readOnly;

  const OrderDetailScreen({
    super.key,
    required this.order,
    required this.onRefresh,
    this.highlightEscalation,
    this.readOnly = false,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  List<OrderItem> _items = [];
  bool _loadingItems = true;
  late bool _itemsExpanded = widget.order.status == 'completed';
  Escalation? _existingEscalation;

  @override
  void initState() {
    super.initState();
    _existingEscalation = widget.highlightEscalation;
    _loadItems();
    if (!widget.readOnly) _checkExistingEscalation();
  }

  Future<void> _loadItems() async {
    setState(() => _loadingItems = true);
    try {
      final items = widget.readOnly
          ? await SuperAdminService.getOrderItems(widget.order.ordersIdorders)
          : await ManagerService.getOrderItems(widget.order.ordersIdorders);
      if (mounted) setState(() => _items = items);
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loadingItems = false);
    }
  }

  Future<void> _checkExistingEscalation() async {
    if (_existingEscalation != null) return; // already known via deep-link
    try {
      final all = await ManagerService.getEscalations();
      if (!mounted) return;
      final match = all.where((e) => e.ordersIdorders == widget.order.ordersIdorders);
      if (match.isNotEmpty) {
        setState(() => _existingEscalation = match.first);
      }
    } catch (_) {}
  }

  int get _pickedCount => _items.where((i) => i.pickerStatus?.pickedStatus == 'picked').length;
  int get _actionedCount => _items.where((i) => i.pickerStatus != null && i.pickerStatus!.pickedStatus != 'pending').length;
  int get _issueCount => _issueItems.length;
  // Issues = full failures (not_available/expired/damaged) + partial picks (picked but qty < ordered)
  List<OrderItem> get _issueItems => _items.where((i) {
        final ps = i.pickerStatus;
        if (ps == null) return false;
        final s = ps.pickedStatus;
        if (s == 'pending') return false;
        if (s == 'picked') return ps.pickedQuantity < i.orderedQuantity;
        return true;
      }).toList();

  Future<void> _showAssignDialog() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Assign Order', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Assign Order #${widget.order.ordersIdorders} to the next available picker via round-robin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Assign')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ManagerService.assignOrder(
        ordersIdorders: widget.order.ordersIdorders,
        storeCode: widget.order.storeCode,
        projectCode: widget.order.projectCode,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order assigned via round-robin'), backgroundColor: AppTheme.success),
        );
        widget.onRefresh();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _showReassignDialog() async {
    List<AssignedUser> pickers = [];
    try {
      pickers = await ManagerService.getPickers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
      return;
    }
    if (!mounted) return;
    String? selectedId;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Reassign to Picker', style: TextStyle(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: pickers.length,
              itemBuilder: (_, i) {
                final p = pickers[i];
                final selected = selectedId == p.id;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primaryLight : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? AppTheme.primary : AppTheme.border),
                  ),
                  child: ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: selected ? AppTheme.primary : AppTheme.border,
                      child: Text(
                        p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                        style: TextStyle(color: selected ? Colors.white : AppTheme.textSecondary, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text('${p.activeOrders} active orders', style: const TextStyle(fontSize: 11)),
                    trailing: selected ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20) : null,
                    onTap: () => setDlgState(() => selectedId = p.id),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selectedId == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      try {
                        await ManagerService.reassignOrder(
                          ordersIdorders: widget.order.ordersIdorders,
                          newPickerId: selectedId!,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Order reassigned'), backgroundColor: AppTheme.success),
                          );
                          widget.onRefresh();
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
                          );
                        }
                      }
                    },
              child: const Text('Reassign'),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _printOrder() async {
    try {
      await OrderPdf.shareOrPrint(order: widget.order, items: _items);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate PDF: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  bool _sending = false;
  bool _sentToSuperAdmin = false;

  Future<void> _sendToSuperAdmin() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Send to Super Admin',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'Forward Order #${widget.order.ordersIdorders} to the super admin for review?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _sending = true);
    try {
      await ManagerService.sendOrderToSuperAdmin(widget.order.ordersIdorders);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sentToSuperAdmin = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Order sent to super admin'),
            backgroundColor: AppTheme.success),
      );
      widget.onRefresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _showOrderEscalateDialog() async {
    final ctrl = TextEditingController();
    final assignment = widget.order.currentAssignment;
    if (assignment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No assignment to escalate against')),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error_rounded, color: AppTheme.error, size: 22),
            SizedBox(width: 8),
            Text('Escalate Order', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10)),
              child: Text('Order #${widget.order.ordersIdorders}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Action / instructions',
                hintText: 'e.g. Cancel the not-available items and refund customer',
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Escalate'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final text = ctrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a message before escalating')),
      );
      return;
    }
    try {
      final created = await ManagerService.createEscalation(
        assignmentId: assignment.id,
        ordersIdorders: widget.order.ordersIdorders,
        storeCode: widget.order.storeCode,
        remarkSummary: text,
      );
      if (mounted) {
        setState(() => _existingEscalation = created);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order escalated'), backgroundColor: AppTheme.warning),
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

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final assignment = order.currentAssignment;
    final total = _items.length;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order #${order.ordersIdorders}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            Text(order.storeCode, style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
            onPressed: _loadItems,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= Responsive.phoneMax;
          final maxContent = Responsive.maxContentWidth(constraints.maxWidth);
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContent),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
          if (_existingEscalation != null) ...[
            _EscalationBanner(escalation: _existingEscalation!),
            const SizedBox(height: 12),
          ],
          // Picking Progress
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bar_chart_rounded, size: 22, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    const Text('Picking Progress',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const Spacer(),
                    if (_loadingItems)
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
                const SizedBox(height: 14),
                if (!_loadingItems && total > 0) ...[
                  Row(
                    children: [
                      Expanded(child: _ProgressStat(value: '$_actionedCount/$total', label: 'Actioned', color: AppTheme.primary)),
                      Container(width: 1, height: 40, color: AppTheme.border),
                      Expanded(child: _ProgressStat(value: '$_pickedCount', label: 'Picked', color: AppTheme.success)),
                      Container(width: 1, height: 40, color: AppTheme.border),
                      Expanded(child: _ProgressStat(value: '$_issueCount', label: 'Issues', color: _issueCount > 0 ? AppTheme.error : AppTheme.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: total > 0 ? _actionedCount / total : 0,
                      backgroundColor: AppTheme.border,
                      valueColor: AlwaysStoppedAnimation(
                          _actionedCount == total && total > 0 ? AppTheme.success : AppTheme.primary),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    total > 0 ? '${(_actionedCount / total * 100).round()}% complete' : '0% complete',
                    style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
                  ),
                ] else if (!_loadingItems)
                  const Text('No item data available',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Order Info + Assignment Info (side-by-side on tablets, stacked on phones)
          Builder(builder: (_) {
            final orderInfo = _InfoCard(
              title: 'Order Info',
              icon: Icons.receipt_long_rounded,
              child: Column(
                children: [
                  _InfoRow('Order ID', '#${order.ordersIdorders}'),
                  _InfoRow('Store', order.storeCode),
                  _InfoRow('Total Items', '${order.totalItems}'),
                  _InfoRow('Total Amount', '₹${order.totalAmount.toStringAsFixed(2)}'),
                  if (order.orderDate != null) _InfoRow('Order Date', formatDate(order.orderDate)),
                  if (order.deliveryDate != null) _InfoRow('Delivery Date', order.deliveryDate!),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 130,
                          child: Text('Status', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                        ),
                        StatusBadge(order.status),
                      ],
                    ),
                  ),
                ],
              ),
            );

            final assignmentInfo = assignment == null
                ? null
                : _InfoCard(
                    title: 'Current Assignment',
                    icon: Icons.person_pin_rounded,
                    child: Column(
                      children: [
                        if (assignment.assignedTo != null) ...[
                          _InfoRow('Picker', assignment.assignedTo!.name),
                          _InfoRow('Email', assignment.assignedTo!.email),
                          if (assignment.assignedTo!.phone != null)
                            _InfoRow('Phone', assignment.assignedTo!.phone!),
                        ],
                        _InfoRow('Assigned At', formatDateTime(assignment.assignedAt)),
                        if (assignment.completedAt != null)
                          _InfoRow('Completed At', formatDateTime(assignment.completedAt)),
                        if (assignment.rejectedReason != null)
                          _InfoRow('Reject Reason', assignment.rejectedReason!),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              const Text('Status', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                              const Spacer(),
                              StatusBadge(assignment.status),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );

            if (isWide && assignmentInfo != null) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: orderInfo),
                    const SizedBox(width: 12),
                    Expanded(child: assignmentInfo),
                  ],
                ),
              );
            }
            return Column(
              children: [
                orderInfo,
                if (assignmentInfo != null) ...[
                  const SizedBox(height: 12),
                  assignmentInfo,
                ],
              ],
            );
          }),

          // Issues — items the picker flagged (not_available, expired, damaged, etc.)
          if (!_loadingItems && _issueItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.error_rounded, size: 22, color: AppTheme.error),
                      ),
                      const SizedBox(width: 12),
                      const Text('Issues',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${_issueItems.length}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.error)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(height: 1, color: AppTheme.border),
                  ...List.generate(_issueItems.length, (i) {
                    final item = _issueItems[i];
                    return Column(
                      children: [
                        _ManagerItemRow(item: item),
                        if (i < _issueItems.length - 1) Container(height: 1, color: AppTheme.border),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],

          // Items List
          if (!_loadingItems && _items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tappable header
                  InkWell(
                    onTap: () => setState(() => _itemsExpanded = !_itemsExpanded),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.list_alt_rounded, size: 22, color: AppTheme.primary),
                          ),
                          const SizedBox(width: 12),
                          const Text('Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          const Spacer(),
                          Text('${_items.length} items', style: const TextStyle(fontSize: 14, color: AppTheme.textMuted)),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: _itemsExpanded ? 0 : -0.5,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(Icons.keyboard_arrow_down_rounded, size: 24, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Collapsible content
                  AnimatedCrossFade(
                    firstChild: Column(
                      children: [
                        Container(height: 1, color: AppTheme.border),
                        ...List.generate(_items.length, (i) {
                          final item = _items[i];
                          return Column(
                            children: [
                              _ManagerItemRow(item: item),
                              if (i < _items.length - 1) Container(height: 1, color: AppTheme.border),
                            ],
                          );
                        }),
                      ],
                    ),
                    secondChild: const SizedBox(width: double.infinity),
                    crossFadeState: _itemsExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                    duration: const Duration(milliseconds: 220),
                  ),
                ],
              ),
            ),
          ],
        ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: widget.readOnly ? null : Container(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Completed: send to super admin, then print receipt.
                if (order.status == 'completed') ...[
                  Builder(builder: (_) {
                    final alreadySent =
                        _sentToSuperAdmin || order.sentToSuperAdmin;
                    return SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        icon: Icon(
                          alreadySent
                              ? Icons.check_circle_rounded
                              : Icons.send_rounded,
                          size: 22,
                        ),
                        label: Text(
                          alreadySent
                              ? 'Sent to Super Admin'
                              : 'Send to Super Admin',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: alreadySent
                              ? AppTheme.success
                              : AppTheme.primary,
                        ),
                        onPressed: (_sending || alreadySent)
                            ? null
                            : _sendToSuperAdmin,
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.print_rounded, size: 22),
                      label: const Text('Print',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      onPressed: _items.isEmpty ? null : _printOrder,
                    ),
                  ),
                  // if (_existingEscalation == null) ...[
                  //   const SizedBox(width: 12),
                  //   Expanded(
                  //     child: SizedBox(
                  //       height: 52,
                  //       child: ElevatedButton.icon(
                  //         icon: const Icon(Icons.report_problem_rounded, size: 22),
                  //         label: const Text('Escalate',
                  //             style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  //         style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                  //         onPressed: _showOrderEscalateDialog,
                  //       ),
                  //     ),
                  //   ),
                  // ],
                ]
                // Rejected: picker declined, manager must manually reassign
                else if (assignment != null && assignment.status == 'rejected') ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3F3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Order rejected by picker. Please manually assign to an available picker.',
                            style: TextStyle(fontSize: 12, color: AppTheme.error, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.person_search_rounded, size: 22),
                      label: const Text('Assign to Picker', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      onPressed: _showReassignDialog,
                    ),
                  ),
                ]
                // Pending and never assigned: use round-robin
                else if (order.status == 'pending' && assignment == null)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.assignment_ind_rounded, size: 22),
                      label: const Text('Assign via Round Robin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      onPressed: _showAssignDialog,
                    ),
                  )
                // Active assignment: allow reassignment
                else if (assignment != null &&
                    (assignment.status == 'assigned' || assignment.status == 'in_progress')) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.swap_horiz_rounded, size: 22),
                      label: const Text('Reassign Picker', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      onPressed: _showReassignDialog,
                    ),
