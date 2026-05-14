import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../services/manager_service.dart';
import '../../utils/app_theme.dart';
import 'picker_detail_screen.dart';

class PickersTab extends StatefulWidget {
  const PickersTab({super.key});

  @override
  State<PickersTab> createState() => _PickersTabState();
}

class _PickersTabState extends State<PickersTab> {
  bool _loading = false;
  List<AssignedUser> _pickers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _pickers = await ManagerService.getPickers();
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

  int get _totalActive => _pickers.fold(0, (sum, p) => sum + p.activeOrders);

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          floating: false,
          expandedHeight: 130,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppTheme.border),
          ),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: _PickersHeader(
              pickerCount: _pickers.length,
              totalActive: _totalActive,
              loading: _loading,
              onRefresh: _load,
            ),
          ),
        ),
        if (_loading)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
        else if (_pickers.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(18)),
                    child: const Icon(Icons.people_outline_rounded, size: 36, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 14),
                  const Text('No pickers found', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PickerCard(picker: _pickers[i]),
                ),
                childCount: _pickers.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _PickersHeader extends StatelessWidget {
  final int pickerCount, totalActive;
  final bool loading;
  final VoidCallback onRefresh;

  const _PickersHeader({required this.pickerCount, required this.totalActive, required this.loading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pickers', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                      Text('Active picker workforce', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatBadge(label: 'Pickers', value: '$pickerCount', icon: Icons.people_rounded, color: AppTheme.primary),
                const SizedBox(width: 10),
                _StatBadge(label: 'Active Orders', value: '$totalActive', icon: Icons.assignment_rounded, color: AppTheme.warning),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _StatBadge({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _PickerCard extends StatelessWidget {
  final AssignedUser picker;

  const _PickerCard({required this.picker});

  Color get _loadColor {
    if (picker.activeOrders == 0) return AppTheme.textMuted;
    if (picker.activeOrders <= 2) return AppTheme.success;
    if (picker.activeOrders <= 4) return AppTheme.warning;
    return AppTheme.error;
  }

  String get _loadLabel {
    if (picker.activeOrders == 0) return 'Free';
    if (picker.activeOrders <= 2) return 'Low';
    if (picker.activeOrders <= 4) return 'Medium';
    return 'High';
  }

  @override
  Widget build(BuildContext context) {
    final initials = picker.name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();
    final color = _loadColor;
    final isActive = picker.isActive ?? true;
    final cardOpacity = isActive ? 1.0 : 0.7;

    return Opacity(
      opacity: cardOpacity,
      child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PickerDetailScreen(picker: picker)),
        ),
        child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppTheme.border : AppTheme.warning.withValues(alpha: 0.4),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isActive
                    ? [AppTheme.primary.withValues(alpha: 0.8), AppTheme.primary]
                    : [AppTheme.textMuted.withValues(alpha: 0.7), AppTheme.textMuted],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                initials.isEmpty ? '?' : initials,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        picker.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'Paused',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.warning),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(picker.email, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                if (picker.phone != null)
                  Text(picker.phone!, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${picker.activeOrders}',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(_loadLabel, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
        ),
      ),
      ),
    );
  }
}
