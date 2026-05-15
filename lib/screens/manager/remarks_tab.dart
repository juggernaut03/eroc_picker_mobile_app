import 'package:flutter/material.dart';
import '../../models/item_model.dart';
import '../../services/manager_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/status_badge.dart';

class RemarksTab extends StatefulWidget {
  const RemarksTab({super.key});

  @override
  State<RemarksTab> createState() => _RemarksTabState();
}

class _RemarksTabState extends State<RemarksTab> {
  bool _loading = false;
  List<Remark> _remarks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _remarks = await ManagerService.getAllRemarks();
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
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppTheme.border),
          ),
          title: const Text(
            'Picker Remarks',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          actions: [
            if (!_loading)
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${_remarks.length} remarks',
                  style: const TextStyle(fontSize: 12, color: AppTheme.warning, fontWeight: FontWeight.w700),
                ),
              ),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary)),
          ],
        ),
        if (_loading)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
        else if (_remarks.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(18)),
                    child: const Icon(Icons.chat_bubble_outline_rounded, size: 34, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 14),
                  const Text('No remarks yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  const Text('Picker item remarks will appear here', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
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
                  child: _RemarkCard(remark: _remarks[i]),
                ),
                childCount: _remarks.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _RemarkCard extends StatelessWidget {
  final Remark remark;

  const _RemarkCard({required this.remark});

  @override
  Widget build(BuildContext context) {
    final statusColor = AppTheme.itemStatusColor(remark.pickedStatus);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.inventory_2_outlined, size: 18, color: statusColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        remark.itemName ?? 'Item',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.receipt_outlined, size: 12, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text('Order #${remark.ordersIdorders}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                ItemStatusBadge(remark.pickedStatus),
              ],
            ),
          ),
          if (remark.remark != null)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_quote_rounded, size: 16, color: AppTheme.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(remark.remark!,
                        style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppTheme.textPrimary, height: 1.4)),
                  ),
                ],
              ),
            ),
          Container(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppTheme.primaryLight,
                  child: Text(
                    (remark.pickedBy?.name ?? 'P').substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primary),
                  ),
                ),
                const SizedBox(width: 6),
                Text(remark.pickedBy?.name ?? 'Unknown picker',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                const Spacer(),
                const Icon(Icons.access_time_rounded, size: 12, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text(formatDateTime(remark.pickedAt),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
