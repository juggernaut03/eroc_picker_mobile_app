import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/delivery_route_model.dart';
import '../../utils/app_theme.dart';
import 'delivery_detail_screen.dart';

class RiderRouteScreen extends StatelessWidget {
  final DeliveryRoute route;

  const RiderRouteScreen({super.key, required this.route});

  Future<void> _openFullRoute(BuildContext context) async {
    final url = route.mapsUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No maps URL for this route')),
      );
      return;
    }
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...route.stops]..sort((a, b) => a.sequence.compareTo(b.sequence));
    final done = sorted.where((s) => s.status == 'delivered').length;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('Route · ${route.storeCode}', style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stop $done of ${sorted.length}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  if (route.estimatedDurationMin != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '~${route.estimatedDurationMin} min · ${route.estimatedDistanceKm?.toStringAsFixed(1) ?? '?'} km',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                  if (route.deliverySlot != null) ...[
                    const SizedBox(height: 4),
                    Text('Slot: ${route.deliverySlot}', style: const TextStyle(fontSize: 13)),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _openFullRoute(context),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Navigate full route'),
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...sorted.map((stop) {
            final assignment = stop.assignment;
            final isPending = stop.status == 'pending';
            final isCurrent = route.currentStop?.ordersIdorders == stop.ordersIdorders;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isCurrent
                    ? const BorderSide(color: AppTheme.primary, width: 2)
                    : BorderSide.none,
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: stop.status == 'delivered'
                      ? Colors.green.shade100
                      : stop.status == 'failed'
                          ? Colors.red.shade100
                          : AppTheme.primary.withValues(alpha: 0.1),
                  child: Text('${stop.sequence}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: stop.status == 'delivered' ? Colors.green.shade800 : AppTheme.primary,
                      )),
                ),
                title: Text('Order #${stop.ordersIdorders}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  stop.order?.deliveryDetails ?? stop.status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: isPending && assignment != null
                    ? const Icon(Icons.chevron_right)
                    : Icon(
                        stop.status == 'delivered'
                            ? Icons.check_circle
                            : stop.status == 'failed'
                                ? Icons.cancel
                                : Icons.hourglass_empty,
                        color: stop.status == 'delivered'
                            ? Colors.green
                            : stop.status == 'failed'
                                ? Colors.red
                                : AppTheme.textSecondary,
                      ),
                onTap: isPending && assignment != null
                    ? () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DeliveryDetailScreen(assignment: assignment),
                          ),
                        );
                      }
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }
}
