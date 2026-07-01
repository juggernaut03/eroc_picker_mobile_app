import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../models/delivery_route_model.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/rider_location_tracker.dart';
import '../../services/rider_service.dart';
import '../../utils/address_utils.dart';
import '../../utils/app_theme.dart';
import '../../widgets/status_badge.dart';
import '../auth/login_screen.dart';
import 'delivery_detail_screen.dart';
import 'rider_route_screen.dart';

class RiderDeliveriesScreen extends StatefulWidget {
  const RiderDeliveriesScreen({super.key});

  @override
  State<RiderDeliveriesScreen> createState() => _RiderDeliveriesScreenState();
}

class _RiderDeliveriesScreenState extends State<RiderDeliveriesScreen> {
  bool _loading = false;
  bool _optimizing = false;
  List<DeliveryAssignment> _all = [];
  DeliveryRoute? _activeRoute;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _openDetail(DeliveryAssignment a) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveryDetailScreen(assignment: a),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        RiderService.getMyDeliveries(),
        RiderService.getActiveRoute(),
      ]);
      if (mounted) {
        setState(() {
          _all = results[0] as List<DeliveryAssignment>;
          _activeRoute = results[1] as DeliveryRoute?;
        });
        await RiderLocationTracker.syncWithDeliveries(_all);
      }
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

  Future<void> _startDayRoute() async {
    setState(() => _optimizing = true);
    try {
      double? lat, lng;
      try {
        final pos = await Geolocator.getCurrentPosition();
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {/* fall back to store origin on the server */}

      final route = await RiderService.startMyRoute(latitude: lat, longitude: lng);
      if (!mounted) return;
      setState(() => _activeRoute = route);
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RiderRouteScreen(route: route)),
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _optimizing = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to view your deliveries.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    RiderLocationTracker.stop();
    await context.read<AuthProvider>().logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    int countOf(String s) => _all.where((a) => a.status == s).length;
    final assigned = countOf('assigned');
    final out = countOf('out_for_delivery');
    final delivered = countOf('delivered');
    final failed = countOf('failed');
    final cancelled = countOf('cancelled');
    final active = assigned + out;
    // Rider has deliveries to do but no route built yet → offer to optimize.
    final pendingUnrouted =
        _all.where((a) => a.status == 'assigned' && a.stopSequence == null).length;
    final canStartRoute = _activeRoute == null && pendingUnrouted >= 2;
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: const Text('My Deliveries', style: TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
              IconButton(
                onPressed: _logout,
                tooltip: 'Log out',
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(82),
              child: Container(
                width: double.infinity,
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text('$active active · ${_all.length} total',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        children: [
                          _KpiChip(
                            label: 'Out',
                            count: out,
                            color: const Color(0xFFF59E0B),
                            icon: Icons.local_shipping_rounded,
                          ),
                          _KpiChip(
                            label: 'Assigned',
                            count: assigned,
                            color: AppTheme.primary,
                            icon: Icons.assignment_turned_in_rounded,
                          ),
                          _KpiChip(
                            label: 'Delivered',
                            count: delivered,
                            color: AppTheme.success,
                            icon: Icons.check_circle_rounded,
                          ),
                          _KpiChip(
                            label: 'Failed',
                            count: failed,
                            color: AppTheme.error,
                            icon: Icons.cancel_rounded,
                          ),
                          if (cancelled > 0)
                            _KpiChip(
                              label: 'Cancelled',
                              count: cancelled,
                              color: AppTheme.textSecondary,
                              icon: Icons.do_not_disturb_on_rounded,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (canStartRoute && !_loading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text('$pendingUnrouted deliveries ready',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Build the most fuel- & time-efficient route from your current location.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _optimizing ? null : _startDayRoute,
                          icon: _optimizing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppTheme.primary),
                                )
                              : const Icon(Icons.route_rounded),
                          label: Text(_optimizing ? 'Optimizing…' : "Start day's route"),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_activeRoute != null && !_loading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RiderRouteScreen(route: _activeRoute!),
                        ),
                      );
                      _load();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.route, color: AppTheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Active route',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                Text(
                                  '${_activeRoute!.stops.length} stops · ~${_activeRoute!.estimatedDurationMin ?? '?'} min',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_all.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('No deliveries assigned yet', style: TextStyle(color: AppTheme.textSecondary))),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final a = _all[i];
                    final order = a.order;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openDetail(a),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Order #${a.ordersIdorders}',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                    StatusBadge(a.status, small: true),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      onPressed: () => _openDetail(a),
                                      icon: const Icon(Icons.remove_red_eye_outlined),
                                      iconSize: 20,
                                      color: AppTheme.primary,
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      tooltip: 'View details',
                                    ),
                                  ],
                                ),
                                if (a.stopSequence != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Stop ${a.stopSequence} of route',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                if (order?.deliveryDetails != null)
                                  _AddressBlock(
                                    DeliveryAddress.parse(order!.deliveryDetails),
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  '${a.storeCode} · ${order?.totalItems ?? 0} items',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _all.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Structured customer/address/phone block for a delivery card, parsed from the
/// flat comma-joined `delivery_details` string so it reads as labelled lines
/// instead of one run-on string.
class _AddressBlock extends StatelessWidget {
  final DeliveryAddress addr;
  const _AddressBlock(this.addr);

  @override
  Widget build(BuildContext context) {
    if (addr.isEmpty) {
      return Text(
        addr.raw.isEmpty ? 'No address provided' : addr.raw,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
      );
    }

    final line = addr.fullAddress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (addr.name != null && addr.name!.isNotEmpty)
          Text(
            addr.name!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        if (line.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1, right: 4),
                  child: Icon(Icons.location_on_outlined,
                      size: 14, color: AppTheme.textMuted),
                ),
                Expanded(
                  child: Text(
                    line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        if (addr.phone != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.phone_outlined,
                      size: 14, color: AppTheme.textMuted),
                ),
                Text(
                  addr.phone!,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Compact status-count chip for the rider deliveries summary bar.
class _KpiChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _KpiChip({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final dim = count == 0;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: dim ? Colors.grey.shade100 : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dim ? AppTheme.border : color.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: dim ? AppTheme.textMuted : color),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: dim ? AppTheme.textMuted : color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: dim ? AppTheme.textMuted : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
