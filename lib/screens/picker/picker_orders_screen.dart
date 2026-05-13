import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/picker_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/helpers.dart';
import '../../utils/responsive.dart';
import '../../widgets/status_badge.dart';
import 'order_items_screen.dart';
import '../auth/login_screen.dart';

class PickerOrdersScreen extends StatefulWidget {
  const PickerOrdersScreen({super.key});

  @override
  State<PickerOrdersScreen> createState() => _PickerOrdersScreenState();
}

class _PickerOrdersScreenState extends State<PickerOrdersScreen> {
  bool _loading = false;
  List<Assignment> _all = [];
  String? _activeFilter; // null = All
  late DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  final List<String?> _statuses = [null, 'assigned', 'in_progress', 'completed', 'rejected'];
  final List<String> _labels = ['All', 'Assigned', 'In Progress', 'Completed', 'Rejected'];

  bool _inSelectedMonth(Assignment a) {
    final d = a.assignedAt;
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
      setState(() => _selectedMonth = DateTime(picked.year, picked.month));
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final orders = await PickerService.getMyOrders();
      if (mounted) setState(() => _all = orders);
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

  List<Assignment> get _monthScoped => _all.where(_inSelectedMonth).toList();

  List<Assignment> _filtered(String? status) {
    final base = _monthScoped;
    return status == null ? base : base.where((a) => a.status == status).toList();
  }

  int _count(String? s) => _filtered(s).length;

  bool _savingAvailability = false;

  Future<void> _toggleAvailability(bool next) async {
    if (_savingAvailability) return;
    setState(() => _savingAvailability = true);
    try {
      await context.read<AuthProvider>().setAvailability(next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next
              ? "You're available — new orders can be assigned to you"
              : "You're paused — new orders will skip you"),
          backgroundColor: next ? AppTheme.success : AppTheme.warning,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _savingAvailability = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final inProgress = _count('in_progress');
    final completed = _count('completed');
    final assigned = _count('assigned');
    final total = _monthScoped.length;

    return Scaffold(
      backgroundColor: const Color(0xFF6C3CE1),
      body: Column(
        children: [
          // ── Hero header ────────────────────────────────────────────
          _PickerHeroHeader(
            user: user,
            total: total,
            assigned: assigned,
            inProgress: inProgress,
            completed: completed,
            loading: _loading,
            onRefresh: _loadAll,
            selectedMonth: _selectedMonth,
            onPrevMonth: () => _changeMonth(-1),
            onNextMonth: () => _changeMonth(1),
            onPickMonth: _pickMonth,
            isActive: user?.isActive ?? true,
            savingAvailability: _savingAvailability,
            onToggleAvailability: _toggleAvailability,
          ),

          // ── Body card ──────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF4F3FA),
              ),
              child: Column(
                children: [
                  _FilterBar(
                    statuses: _statuses,
                    labels: _labels,
                    selected: _activeFilter,
                    counts: {for (final s in _statuses) s: _count(s)},
                    onSelect: (s) => setState(() => _activeFilter = s),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C3CE1)))
                        : _AssignmentList(
                            assignments: _filtered(_activeFilter),
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
// Hero header — teal-purple gradient for picker (different from manager)
// ─────────────────────────────────────────────────────────────────────────────
class _PickerHeroHeader extends StatelessWidget {
  final dynamic user;
  final int total, assigned, inProgress, completed;
  final bool loading;
  final VoidCallback onRefresh;
  final DateTime selectedMonth;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onPickMonth;
  final bool isActive;
  final bool savingAvailability;
  final ValueChanged<bool> onToggleAvailability;

  const _PickerHeroHeader({
    required this.user,
    required this.total,
    required this.assigned,
    required this.inProgress,
    required this.completed,
    required this.loading,
    required this.onRefresh,
    required this.selectedMonth,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onPickMonth,
    required this.isActive,
    required this.savingAvailability,
    required this.onToggleAvailability,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F4C81), Color(0xFF1565C0), Color(0xFF1E88E5)],
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
                  _PickerAvatar(name: user?.name ?? 'P'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user?.name ?? 'Picker',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Picker · ${user?.storeCodes?.join(' · ') ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  _PickerDateChip(
                    selected: selectedMonth,
                    onPrev: onPrevMonth,
                    onNext: onNextMonth,
                    onPick: onPickMonth,
                  ),
                  IconButton(
                    onPressed: onRefresh,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: const EdgeInsets.all(6),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 18),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                          'My assigned orders',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (inProgress > 0) ...[
                        const SizedBox(width: 6),
                        _LiveBadge(count: inProgress, label: 'picking'),
                      ],
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.only(left: 8, bottom: 4),
                          child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Availability strip — picker self-toggles is_active
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _AvailabilityStrip(
                isActive: isActive,
                saving: savingAvailability,
                onChanged: onToggleAvailability,
              ),
            ),

            const SizedBox(height: 10),

            // KPI cards
            SizedBox(
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _KpiCard(
                    label: 'Assigned',
                    value: '$assigned',
                    icon: Icons.assignment_rounded,
                    iconColor: const Color(0xFFFBBF24),
                    delta: '',
                  ),
                  _KpiCard(
                    label: 'Picking',
                    value: '$inProgress',
                    icon: Icons.local_shipping_rounded,
                    iconColor: const Color(0xFF34D399),
                    delta: '',
                  ),
                  _KpiCard(
                    label: 'Completed',
                    value: '$completed',
                    icon: Icons.check_circle_rounded,
                    iconColor: const Color(0xFF60A5FA),
                    delta: total > 0 ? '+${(completed / total * 100).round()}%' : '',
                    positive: true,
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

class _PickerAvatar extends StatelessWidget {
  final String name;
  const _PickerAvatar({required this.name});

  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'P',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
      );
}

class _AvailabilityStrip extends StatelessWidget {
  final bool isActive;
  final bool saving;
  final ValueChanged<bool> onChanged;

  const _AvailabilityStrip({
    required this.isActive,
    required this.saving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isActive ? const Color(0xFF34D399) : const Color(0xFFFBBF24);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle, boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 6),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isActive ? 'Available for new orders' : 'Paused — not accepting new orders',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (saving)
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          else
            Transform.scale(
              scale: 0.8,
              child: Switch.adaptive(
                value: isActive,
                activeColor: const Color(0xFF34D399),
                onChanged: onChanged,
              ),
            ),
        ],
      ),
    );
  }
}

class _PickerDateChip extends StatelessWidget {
  final DateTime selected;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;

  const _PickerDateChip({
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
  final String label;
  const _LiveBadge({required this.count, required this.label});

  @override
  Widget build(BuildContext context) => Container(
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
            Text('$count $label', style: const TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _KpiCard extends StatelessWidget {
  final String label, value, delta;
  final IconData icon;
  final Color iconColor;
  final bool positive;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.delta,
    this.positive = true,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: 120,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(7)),
              child: Icon(icon, color: iconColor, size: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, height: 1.1)),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 10, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            if (delta.isNotEmpty)
              Text(delta, style: TextStyle(color: positive ? const Color(0xFF34D399) : const Color(0xFFF87171), fontSize: 9, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter bar
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
                  color: isSelected ? const Color(0xFF1565C0) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [BoxShadow(color: const Color(0xFF1565C0).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
                      : [],
                  border: Border.all(color: isSelected ? const Color(0xFF1565C0) : const Color(0xFFE2E8F0)),
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
                          color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF1565C0).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : const Color(0xFF1565C0),
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
// Assignment list + card
// ─────────────────────────────────────────────────────────────────────────────
class _AssignmentList extends StatelessWidget {
  final List<Assignment> assignments;
  final VoidCallback onRefresh;

  const _AssignmentList({required this.assignments, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (assignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
              ]),
              child: const Icon(Icons.inbox_rounded, size: 36, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            const Text('No orders assigned yet', style: TextStyle(color: Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Your manager will assign orders to you. Pull down to refresh.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: const Color(0xFF1565C0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = Responsive.columnsFor(width);
          final maxContent = Responsive.maxContentWidth(width);

          if (columns == 1) {
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: assignments.length,
              itemBuilder: (ctx, i) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _AssignmentCard(
                    assignment: assignments[i], onRefresh: onRefresh),
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
                  mainAxisExtent: 180,
                ),
                itemCount: assignments.length,
                itemBuilder: (ctx, i) => _AssignmentCard(
                    assignment: assignments[i], onRefresh: onRefresh),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final Assignment assignment;
  final VoidCallback onRefresh;

  const _AssignmentCard({required this.assignment, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final order = assignment.order;
    final canPick = assignment.status == 'assigned' || assignment.status == 'in_progress';
    final canOpen = canPick || assignment.status == 'completed';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: canOpen
            ? () async {
                final refreshed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => OrderItemsScreen(assignment: assignment)),
                );
                if (refreshed == true) onRefresh();
              }
            : null,
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
                              'Order #${assignment.ordersIdorders}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A)),
                            ),
                          ),
                          StatusBadge(assignment.status, small: true),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          if (order != null) ...[
                            _MetaChip(Icons.store_rounded, order.storeCode),
                            _MetaChip(Icons.shopping_bag_rounded, '${order.totalItems} items'),
                            _MetaChip(Icons.currency_rupee_rounded, order.totalAmount.toStringAsFixed(0)),
                            if (order.deliveryDate != null)
                              _MetaChip(Icons.local_shipping_outlined, 'Deliver by ${order.deliveryDate}'),
                          ],
                          _MetaChip(Icons.access_time_rounded, 'Assigned ${formatDateTime(assignment.assignedAt)}'),
                        ],
                      ),
                      if (assignment.rejectedReason != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFF87171).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_rounded, size: 14, color: Color(0xFFDC2626)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  assignment.rejectedReason!,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (canPick) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              assignment.status == 'in_progress' ? 'Continue picking' : 'Start picking',
                              style: const TextStyle(color: Color(0xFF1565C0), fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF1565C0)),
                          ],
                        ),
                      ] else if (assignment.status == 'completed') ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text(
                              'View picked items',
                              style: TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF16A34A)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              if (canOpen)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: const Color(0xFFF4F3FA), borderRadius: BorderRadius.circular(8)),
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
