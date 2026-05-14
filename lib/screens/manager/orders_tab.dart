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
  // First day of the currently selected month — used to filter orders by orderDate.
  late DateTime _selectedMonth = _firstOfMonth(DateTime.now());

  final List<String?> _statuses = [null, 'pending', 'assigned', 'in_progress', 'completed', 'rejected'];
  final List<String> _labels = ['All', 'Pending', 'Assigned', 'In Progress', 'Completed', 'Rejected'];

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

  int _count(String? status) => _filtered(status).length;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final total = _monthScoped.length;
    final pending = _count('pending');
    final inProgress = _count('in_progress');
    final completed = _count('completed');
    final assigned = _count('assigned');
    final rejected = _count('rejected');

    return Scaffold(
      backgroundColor: const Color(0xFF6C3CE1),
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
                  // Filter chip row
                  _FilterBar(
                    statuses: _statuses,
                    labels: _labels,
                    selected: _activeFilter,
                    counts: {for (final s in _statuses) s: _count(s)},
                    onSelect: (s) => setState(() => _activeFilter = s),
                  ),

                  // Order list
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C3CE1)))
                        : _OrderList(
                            orders: _filtered(_activeFilter),
                            onRefresh: _loadAll,
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
