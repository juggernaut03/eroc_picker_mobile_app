import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../services/manager_service.dart';
import '../../utils/app_theme.dart';
import 'rider_detail_screen.dart';

class RidersTab extends StatefulWidget {
  const RidersTab({super.key});

  @override
  State<RidersTab> createState() => _RidersTabState();
}

class _RidersTabState extends State<RidersTab> {
  bool _loading = false;
  List<AssignedUser> _riders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _riders = await ManagerService.getRiders();
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

  int get _totalActive => _riders.fold(0, (sum, r) => sum + r.activeOrders);

  Future<void> _openRider(AssignedUser rider) async {
    try {
      final res = await ManagerService.getRider(rider.id);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RiderDetailScreen(rider: res.rider, deliveries: res.deliveries),
        ),
      );
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
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Material(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
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
                              Text('Riders', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                              Text('Delivery workforce', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${_riders.length} riders · $_totalActive active deliveries',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_loading)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
        else if (_riders.isEmpty)
          const SliverFillRemaining(
            child: Center(child: Text('No riders found', style: TextStyle(color: AppTheme.textSecondary))),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final r = _riders[i];
                  final initials = r.name.isNotEmpty ? r.name[0].toUpperCase() : '?';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openRider(r),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                                child: Text(initials, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                    Text(r.email, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${r.activeOrders}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.primary)),
                                  const Text('active', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: _riders.length,
              ),
            ),
          ),
      ],
    );
  }
}
