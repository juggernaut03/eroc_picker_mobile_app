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

class _EscalationCard extends StatelessWidget {
  final Escalation escalation;
  final VoidCallback onRefresh;

  const _EscalationCard({required this.escalation, required this.onRefresh});

  Future<void> _openOrder(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final loaderEntry = OverlayEntry(
      builder: (_) => Container(
        color: Colors.black.withValues(alpha: 0.25),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
    Overlay.of(context).insert(loaderEntry);
    try {
      final order = await ManagerService.getOrder(escalation.ordersIdorders);
      loaderEntry.remove();
      if (order == null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Order not found'), backgroundColor: AppTheme.error),
        );
        return;
      }
      navigator.push(
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(
            order: order,
            onRefresh: onRefresh,
            highlightEscalation: escalation,
          ),
        ),
      );
    } catch (e) {
      loaderEntry.remove();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = escalation.isOpen;
    final accentColor = isOpen ? AppTheme.error : AppTheme.success;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openOrder(context),
        child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isOpen ? AppTheme.error.withValues(alpha: 0.2) : AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isOpen ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order #${escalation.ordersIdorders}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      if (escalation.itemName != null)
                        Text(escalation.itemName!,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(formatDateTime(escalation.createdAt),
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    isOpen ? 'Open' : 'Resolved',
                    style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(escalation.remarkSummary,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.4)),
                  if (escalation.raisedByName != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 13, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text('Raised by ${escalation.raisedByName}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (escalation.resolutionNote != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: AppTheme.successLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 15, color: AppTheme.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Resolution', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.success)),
                          const SizedBox(height: 2),
                          Text(escalation.resolutionNote!,
                              style: const TextStyle(fontSize: 12, color: AppTheme.success, height: 1.4)),
                        ],
                      ),
                    ),
                    if (escalation.resolvedAt != null)
                      Text(formatDateTime(escalation.resolvedAt),
                          style: TextStyle(fontSize: 10, color: AppTheme.success.withValues(alpha: 0.7))),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
        ),
      ),
    );
  }
}
