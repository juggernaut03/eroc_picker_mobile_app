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
