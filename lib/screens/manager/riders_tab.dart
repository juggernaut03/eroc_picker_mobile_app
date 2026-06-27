import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../services/manager_service.dart';
import '../../utils/app_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            background: SafeArea(
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
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      leading: CircleAvatar(child: Text(r.name.isNotEmpty ? r.name[0] : '?')),
                      title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${r.activeOrders} active deliveries'),
                      trailing: (r.isActive ?? true)
                          ? const Icon(Icons.circle, color: AppTheme.success, size: 10)
                          : const Icon(Icons.circle, color: AppTheme.textMuted, size: 10),
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
