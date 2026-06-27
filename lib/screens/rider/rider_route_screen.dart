import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/delivery_route_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/geo_utils.dart';
import '../../utils/nav_launcher.dart';
import '../../widgets/live_nav_map.dart';
import 'delivery_detail_screen.dart';

class RiderRouteScreen extends StatelessWidget {
  final DeliveryRoute route;

  const RiderRouteScreen({super.key, required this.route});

  /// Open the multi-stop route in a maps app if the backend provided a full
  /// route URL; otherwise hand off turn-by-turn to the next pending stop.
  Future<void> _openFullRoute(BuildContext context) async {
    final url = route.mapsUrl;
    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    }
    if (!context.mounted) return;

    final next = route.currentStop ??
        route.stops.firstWhere(
          (s) => s.status == 'pending',
          orElse: () => route.stops.first,
        );
    final dest = parseDeliveryLatLng(next.latitude, next.longitude);
    if (dest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid coordinates for the next stop')),
      );
      return;
    }
    await NavLauncher.navigateTo(
      context,
      destLat: dest.latitude,
      destLng: dest.longitude,
      label: 'Stop ${next.sequence}',
    );
  }

  List<NavStop> _navStops() {
    final out = <NavStop>[];
    for (final s in route.stops) {
      final p = parseDeliveryLatLng(s.latitude, s.longitude);
      if (p == null) continue;
      out.add(NavStop(
        point: p,
        sequence: s.sequence,
        isDone: s.status == 'delivered',
        isCurrent: route.currentStop?.ordersIdorders == s.ordersIdorders,
      ));
    }
    return out;
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
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () => _openFullRoute(context),
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('Navigate to next stop'),
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                    ),
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
          if (_navStops().isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Route map', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            LiveNavMap(stops: _navStops(), height: 260),
          ],
        ],
      ),
    );
  }
}
