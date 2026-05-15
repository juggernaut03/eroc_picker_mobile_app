import 'package:flutter/material.dart';
import '../../models/item_model.dart';
import '../../services/manager_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/helpers.dart';
import 'order_detail_screen.dart';

class EscalationsTab extends StatefulWidget {
  const EscalationsTab({super.key});

  @override
  State<EscalationsTab> createState() => EscalationsTabState();
}

class EscalationsTabState extends State<EscalationsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _loading = false;
  List<Escalation> _open = [];
  List<Escalation> _all = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  /// Public refresh so the parent screen can call it when the tab is focused.
  Future<void> reload() => _load();

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ManagerService.getEscalations(status: 'open'),
        ManagerService.getEscalations(),
      ]);
      setState(() {
        _open = results[0];
        _all = results[1];
      });
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

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverAppBar(
          pinned: true,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text(
            'Escalations',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary)),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  Container(height: 1, color: AppTheme.border),
                  TabBar(
                    controller: _tab,
                    labelColor: AppTheme.primary,
                    unselectedLabelColor: AppTheme.textSecondary,
                    indicatorColor: AppTheme.primary,
                    indicatorWeight: 3,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Open'),
                            if (_open.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_open.length}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.error, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('All'),
                            if (_all.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.textMuted.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_all.length}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                _EscalationList(escalations: _open, onRefresh: _load),
                _EscalationList(escalations: _all, onRefresh: _load),
              ],
            ),
    );
  }
}

class _EscalationList extends StatelessWidget {
  final List<Escalation> escalations;
  final VoidCallback onRefresh;

  const _EscalationList({required this.escalations, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (escalations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.check_circle_outline_rounded, size: 36, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            const Text('No escalations', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            const Text("You're all clear", style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: escalations.length,
        itemBuilder: (ctx, i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _EscalationCard(escalation: escalations[i], onRefresh: onRefresh),
        ),
      ),
    );
  }
}

