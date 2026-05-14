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
