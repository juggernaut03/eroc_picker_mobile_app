import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/delivery_route_model.dart';
import '../../models/order_model.dart';
import '../../services/rider_location_tracker.dart';
import '../../services/rider_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/status_badge.dart';
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

  @override
  Widget build(BuildContext context) {
    final active = _all.where((a) => a.status == 'assigned' || a.status == 'out_for_delivery').length;
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
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                color: Colors.white,
                child: Text('$active active · ${_all.length} total',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DeliveryDetailScreen(assignment: a),
                              ),
                            );
                            _load();
                          },
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
                                  Text(
                                    order!.deliveryDetails!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                  ),
                                const SizedBox(height: 6),
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
