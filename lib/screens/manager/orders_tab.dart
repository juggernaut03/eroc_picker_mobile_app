import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/manager_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/helpers.dart';
import '../../utils/responsive.dart';
import '../../widgets/status_badge.dart';
import 'order_detail_screen.dart';
import 'create_route_screen.dart';
import '../auth/login_screen.dart';

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _loading = false;
  List<Order> _allOrders = [];
  String? _activeFilter;
  bool _deliveryView = false;
  late DateTime _selectedMonth = _firstOfMonth(DateTime.now());

  final List<String?> _statuses = [null, 'pending', 'assigned', 'in_progress', 'completed', 'rejected'];
  final List<String> _labels = ['All', 'Pending', 'Assigned', 'In Progress', 'Completed', 'Rejected'];

  final List<String?> _deliveryStatuses = [
    null,
    'ready_for_delivery',
    'assigned',
    'out_for_delivery',
    'delivered',
    'failed',
  ];
  final List<String> _deliveryLabels = [
    'All',
    'Ready',
    'Assigned',
    'Out',
    'Delivered',
    'Failed',
  ];

  static DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month);

  bool _inSelectedMonth(Order o) {
    final d = o.orderDate;
    if (d == null) return false;
    return d.year == _selectedMonth.year && d.month == _selectedMonth.month;
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 2, 12),
      helpText: 'Select month',
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() => _selectedMonth = _firstOfMonth(picked));
    }
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final orders = await ManagerService.getAllOrders();
      if (mounted) setState(() => _allOrders = orders);
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

  List<Order> get _monthScoped => _allOrders.where(_inSelectedMonth).toList();

  List<Order> _filtered(String? status) {
    final base = _monthScoped;
    return status == null ? base : base.where((o) => o.status == status).toList();
  }

  List<Order> _deliveryFiltered(String? deliveryStatus) {
    final base = _monthScoped.where((o) => o.status == 'completed').toList();
    if (deliveryStatus == null) {
      return base.where((o) => o.deliveryStatus != null && o.deliveryStatus!.isNotEmpty).toList();
    }
    return base.where((o) => o.deliveryStatus == deliveryStatus).toList();
  }

  int _count(String? status) => _filtered(status).length;

  int _deliveryCount(String? deliveryStatus) => _deliveryFiltered(deliveryStatus).length;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final ui = context.watch<AuthProvider>().uiConfig;
    bool cap(String key) => ui == null ? true : ui.can(key);
    final total = _monthScoped.length;
    final pending = _count('pending');
    final inProgress = _count('in_progress');
    final completed = _count('completed');
    final assigned = _count('assigned');
    final rejected = _count('rejected');

    return Scaffold(
      backgroundColor: const Color(0xFF6C3CE1),
      floatingActionButton: cap('can_create_delivery_route')
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateRouteScreen()),
                );
                if (created == true) _loadAll();
              },
              backgroundColor: const Color(0xFF6C3CE1),
              icon: const Icon(Icons.route),
              label: const Text('Route'),
            )
          : null,
      body: Column(
        children: [
          // ── Hero header ──────────────────────────────────────────────
          _HeroHeader(
            user: user,
            total: total,
            pending: pending,
            assigned: assigned,
            inProgress: inProgress,
            completed: completed,
            rejected: rejected,
            loading: _loading,
            onRefresh: _loadAll,
            selectedMonth: _selectedMonth,
            onPrevMonth: () => _changeMonth(-1),
            onNextMonth: () => _changeMonth(1),
            onPickMonth: _pickMonth,
          ),

          // ── Body card ────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF4F3FA),
              ),
              child: Column(
                children: [
                  if (cap('can_view_delivery_status'))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Picking'), icon: Icon(Icons.inventory_2_outlined, size: 18)),
                          ButtonSegment(value: true, label: Text('Delivery'), icon: Icon(Icons.local_shipping_outlined, size: 18)),
                        ],
                        selected: {_deliveryView},
                        onSelectionChanged: (s) {
                          setState(() {
                            _deliveryView = s.first;
                            _activeFilter = null;
                          });
                        },
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  _FilterBar(
                    statuses: _deliveryView ? _deliveryStatuses : _statuses,
                    labels: _deliveryView ? _deliveryLabels : _labels,
                    selected: _activeFilter,
                    counts: {
                      for (final s in (_deliveryView ? _deliveryStatuses : _statuses))
                        s: _deliveryView ? _deliveryCount(s) : _count(s),
                    },
                    onSelect: (s) => setState(() => _activeFilter = s),
                  ),

                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C3CE1)))
                        : _OrderList(
                            orders: _deliveryView
                                ? _deliveryFiltered(_activeFilter)
                                : _filtered(_activeFilter),
                            onRefresh: _loadAll,
                            showDeliveryBadge: _deliveryView,
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
// Hero header — purple gradient, greeting, KPI cards row
// ─────────────────────────────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final PickerUser? user;
  final int total, pending, assigned, inProgress, completed, rejected;
  final bool loading;
  final VoidCallback onRefresh;
  final DateTime selectedMonth;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onPickMonth;

  const _HeroHeader({
    required this.user,
    required this.total,
    required this.pending,
    required this.assigned,
    required this.inProgress,
    required this.completed,
    required this.rejected,
    required this.loading,
    required this.onRefresh,
    required this.selectedMonth,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onPickMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4B1FA8), Color(0xFF6C3CE1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  // Avatar + name
                  _BlobAvatar(name: user?.name ?? 'M'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user?.name ?? 'Store Manager',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          user?.storeCodes.join(' · ') ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Date chip
                  _DateChip(
                    selected: selectedMonth,
                    onPrev: onPrevMonth,
                    onNext: onNextMonth,
                    onPick: onPickMonth,
                  ),
                  IconButton(
                    onPressed: () async {
                      await context.read<AuthProvider>().logout();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: const EdgeInsets.all(6),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 18),
                  ),
                ],
              ),
            ),

            // Big metric
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$total',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Total orders today',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (inProgress > 0) ...[
                    const SizedBox(width: 6),
                    _LiveBadge(count: inProgress),
                  ],
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.only(left: 8, bottom: 4),
                      child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // KPI cards row — horizontal scroll
            SizedBox(
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _KpiCard(
                    label: 'Pending',
                    value: '$pending',
                    delta: '',
                    icon: Icons.schedule_rounded,
                    iconColor: const Color(0xFFFBBF24),
                    bg: Colors.white.withValues(alpha: 0.15),
                  ),
                  _KpiCard(
                    label: 'In Progress',
                    value: '$inProgress',
                    delta: '',
                    icon: Icons.local_shipping_rounded,
                    iconColor: const Color(0xFF34D399),
                    bg: Colors.white.withValues(alpha: 0.15),
                  ),
                  _KpiCard(
                    label: 'Completed',
                    value: '$completed',
                    delta: total > 0 ? '+${(completed / total * 100).round()}%' : '',
                    icon: Icons.check_circle_rounded,
                    iconColor: const Color(0xFF60A5FA),
                    bg: Colors.white.withValues(alpha: 0.15),
                    positive: true,
                  ),
                  _KpiCard(
                    label: 'Assigned',
                    value: '$assigned',
                    delta: '',
                    icon: Icons.assignment_ind_rounded,
                    iconColor: const Color(0xFFC084FC),
                    bg: Colors.white.withValues(alpha: 0.15),
                  ),
                  _KpiCard(
                    label: 'Rejected',
                    value: '$rejected',
                    delta: rejected > 0 ? '-${(rejected / total * 100).round()}%' : '',
                    icon: Icons.cancel_rounded,
                    iconColor: const Color(0xFFF87171),
                    bg: Colors.white.withValues(alpha: 0.15),
                    positive: false,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _BlobAvatar extends StatelessWidget {
  final String name;
  const _BlobAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFE879F9), Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'M',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final DateTime selected;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;

  const _DateChip({
    required this.selected,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final label = '${months[selected.month - 1]} ${selected.year.toString().substring(2)}';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onPrev,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(8, 5, 2, 5),
              child: Icon(Icons.chevron_left, color: Colors.white, size: 14),
            ),
          ),
          InkWell(
            onTap: onPick,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          InkWell(
            onTap: onNext,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(2, 5, 8, 5),
              child: Icon(Icons.chevron_right, color: Colors.white, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final int count;
  const _LiveBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF34D399).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('$count active', style: const TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label, value, delta;
  final IconData icon;
  final Color iconColor, bg;
  final bool positive;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.delta,
    required this.icon,
    required this.iconColor,
    required this.bg,
    this.positive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, color: iconColor, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, height: 1.1)),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 10, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (delta.isNotEmpty)
            Text(
              delta,
              style: TextStyle(
                color: positive ? const Color(0xFF34D399) : const Color(0xFFF87171),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter bar — pill chips
// ─────────────────────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final List<String?> statuses;
  final List<String> labels;
  final String? selected;
  final Map<String?, int> counts;
  final ValueChanged<String?> onSelect;

  const _FilterBar({
    required this.statuses,
    required this.labels,
    required this.selected,
    required this.counts,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 6),
      child: SizedBox(
        height: 38,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: statuses.length,
          itemBuilder: (_, i) {
            final s = statuses[i];
            final isSelected = selected == s;
            final count = counts[s] ?? 0;
            return GestureDetector(
              onTap: () => onSelect(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF6C3CE1) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [BoxShadow(color: const Color(0xFF6C3CE1).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
                      : [],
                  border: Border.all(
                    color: isSelected ? const Color(0xFF6C3CE1) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      labels[i],
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF6C3CE1).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : const Color(0xFF6C3CE1),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order list
// ─────────────────────────────────────────────────────────────────────────────
class _OrderList extends StatelessWidget {
  final List<Order> orders;
  final VoidCallback onRefresh;
  final bool showDeliveryBadge;

  const _OrderList({
    required this.orders,
    required this.onRefresh,
    this.showDeliveryBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
              ]),
              child: const Icon(Icons.inbox_rounded, size: 36, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            const Text('No orders here', style: TextStyle(color: Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Pull down to refresh', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: const Color(0xFF6C3CE1),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = Responsive.columnsFor(width);
          final maxContent = Responsive.maxContentWidth(width);

          if (columns == 1) {
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: orders.length,
              itemBuilder: (ctx, i) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _OrderCard(order: orders[i], onRefresh: onRefresh, showDeliveryBadge: showDeliveryBadge),
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContent),
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 170,
                ),
                itemCount: orders.length,
                itemBuilder: (ctx, i) =>
                    _OrderCard(order: orders[i], onRefresh: onRefresh, showDeliveryBadge: showDeliveryBadge),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order card — inspired by the reference's grocery row style
// ─────────────────────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onRefresh;
  final bool showDeliveryBadge;

  const _OrderCard({
    required this.order,
    required this.onRefresh,
    this.showDeliveryBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final assignment = order.currentAssignment;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order, onRefresh: onRefresh)),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Order #${order.ordersIdorders}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A)),
                            ),
                          ),
                          if (showDeliveryBadge && order.deliveryStatus != null)
                            StatusBadge(order.deliveryStatus!, small: true),
                          if (!showDeliveryBadge || order.deliveryStatus == null)
                            StatusBadge(order.status, small: true),
                          if (!showDeliveryBadge && order.deliveryStatus != null) ...[
                            const SizedBox(width: 6),
                            StatusBadge(order.deliveryStatus!, small: true),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          _MetaChip(Icons.store_rounded, order.storeCode),
                          _MetaChip(Icons.shopping_bag_rounded, '${order.totalItems} items'),
                          _MetaChip(Icons.currency_rupee_rounded, order.totalAmount.toStringAsFixed(0)),
                          if (order.orderDate != null)
                            _MetaChip(Icons.calendar_today_rounded, formatDate(order.orderDate)),
                        ],
                      ),
                      if (assignment != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F5FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF6C3CE1).withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: const Color(0xFF6C3CE1),
                                child: Text(
                                  (assignment.assignedTo?.name ?? 'P')[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  assignment.assignedTo?.name ?? 'Assigned',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6C3CE1)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              StatusBadge(assignment.status, small: true),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Arrow
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F3FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      );
}
