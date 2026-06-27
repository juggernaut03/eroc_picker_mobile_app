import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../services/manager_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/status_badge.dart';

class RiderDetailScreen extends StatefulWidget {
  final AssignedUser rider;
  final List<DeliveryAssignment> deliveries;

  const RiderDetailScreen({
    super.key,
    required this.rider,
    required this.deliveries,
  });

  @override
  State<RiderDetailScreen> createState() => _RiderDetailScreenState();
}

class _RiderDetailScreenState extends State<RiderDetailScreen> {
  Map<String, dynamic>? _location;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final list = await ManagerService.getRiderLocations();
      final match = list.where((e) => e['rider_id']?.toString() == widget.rider.id).toList();
      if (mounted && match.isNotEmpty) setState(() => _location = match.first);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final rider = widget.rider;
    final deliveries = widget.deliveries;
    final initials = rider.name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();
    final active = deliveries.where((d) => d.status == 'assigned' || d.status == 'out_for_delivery').length;
    final delivered = deliveries.where((d) => d.status == 'delivered').length;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Rider Details', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primary,
                  child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rider.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(rider.email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      if (rider.phone != null) Text(rider.phone!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_location != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Last GPS ping', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(
                          '${_location!['last_location']['latitude']}, ${_location!['last_location']['longitude']}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatCard('Active', '$active', AppTheme.warning)),
              const SizedBox(width: 10),
              Expanded(child: _StatCard('Delivered', '$delivered', AppTheme.success)),
              const SizedBox(width: 10),
              Expanded(child: _StatCard('Load now', '${rider.activeOrders}', AppTheme.primary)),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Recent deliveries', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (deliveries.isEmpty)
            const Text('No deliveries yet', style: TextStyle(color: AppTheme.textSecondary))
          else
            ...deliveries.map((d) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Order #${d.ordersIdorders}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(formatDateTime(d.assignedAt), style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                      StatusBadge(d.status, small: true),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}
