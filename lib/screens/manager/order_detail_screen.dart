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
