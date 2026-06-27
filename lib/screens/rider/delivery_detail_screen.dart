import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/rider_location_tracker.dart';
import '../../services/rider_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/geo_utils.dart';
import '../../utils/nav_launcher.dart';
import '../../widgets/live_nav_map.dart';
import '../../widgets/status_badge.dart';
import 'pod_screen.dart';

class DeliveryDetailScreen extends StatefulWidget {
  final DeliveryAssignment assignment;

  const DeliveryDetailScreen({super.key, required this.assignment});

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  bool _loading = false;
  bool _otpRequired = false;
  bool _arrived = false;
  late DeliveryAssignment _assignment;
  Order? _order;

  @override
  void initState() {
    super.initState();
    _assignment = widget.assignment;
    _order = widget.assignment.order;
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _syncLocationPing() async {
    try {
      final list = await RiderService.getMyDeliveries();
      await RiderLocationTracker.syncWithDeliveries(list);
    } catch (_) {
      await RiderLocationTracker.syncWithDeliveries([_assignment]);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await RiderService.getDeliveryDetail(_assignment.ordersIdorders);
      if (!mounted) return;
      setState(() {
        _assignment = res.assignment;
        _order = res.order ?? _order;
        _otpRequired = res.otpRequired;
      });
      _syncLocationPing();
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool cap(String key) {
    final ui = context.read<AuthProvider>().uiConfig;
    return ui == null ? true : ui.can(key);
  }

  Future<void> _openMaps() async {
    final dest = parseDeliveryLatLng(_order?.latitude, _order?.longitude);
    if (dest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid delivery coordinates for this order')),
      );
      return;
    }
    await NavLauncher.navigateTo(
      context,
      destLat: dest.latitude,
      destLng: dest.longitude,
      label: 'Order #${_assignment.ordersIdorders}',
    );
  }

  void _onArrived() {
    if (_arrived || !mounted) return;
    setState(() => _arrived = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("You've arrived at the delivery location"),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Future<void> _start() async {
    setState(() => _loading = true);
    try {
      await RiderService.startDelivery(_assignment.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery started'), backgroundColor: AppTheme.success),
        );
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

  Future<void> _openPod() async {
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PodScreen(assignment: _assignment, otpRequired: _otpRequired),
      ),
    );
    if (done == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _fail() async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report failed delivery'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(hintText: 'Reason'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true || reasonCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await RiderService.failDelivery(_assignment.id, reasonCtrl.text.trim());
      if (!mounted) return;
      Navigator.pop(context, true);
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
    final order = _order;
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('Order #${_assignment.ordersIdorders}'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              StatusBadge(_assignment.status),
              const SizedBox(width: 8),
              Text(_assignment.storeCode, style: const TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
          if (_assignment.stopSequence != null) ...[
            const SizedBox(height: 8),
            Chip(
              avatar: const Icon(Icons.route, size: 16),
              label: Text('Stop ${_assignment.stopSequence} on route'),
              visualDensity: VisualDensity.compact,
            ),
          ],
          const SizedBox(height: 16),
          Builder(builder: (context) {
            final dest = parseDeliveryLatLng(order?.latitude, order?.longitude);
            if (dest == null) {
              return Container(
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Text('No delivery coordinates on this order',
                    style: TextStyle(color: AppTheme.textSecondary)),
              );
            }
            return LiveNavMap(
              stops: [NavStop(point: dest, isCurrent: true)],
              height: 260,
              onArrived: _onArrived,
            );
          }),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _openMaps,
              icon: const Icon(Icons.navigation_rounded),
              label: const Text('Navigate'),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          if (order?.deliveryDetails != null)
            Text(order!.deliveryDetails!, style: const TextStyle(fontSize: 15)),
          if (order?.deliveryDate != null) ...[
            const SizedBox(height: 8),
            Text('Delivery date: ${order!.deliveryDate}', style: const TextStyle(color: AppTheme.textSecondary)),
          ],
          if (order?.deliverySlot != null) ...[
            const SizedBox(height: 4),
            Text('Slot: ${order!.deliverySlot}', style: const TextStyle(color: AppTheme.textSecondary)),
          ],
          if (_assignment.status == 'out_for_delivery') ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.gps_fixed, size: 16, color: AppTheme.textSecondary),
                SizedBox(width: 6),
                Text('Live location sharing active', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: _assignment.status == 'delivered' || _assignment.status == 'failed'
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_assignment.status == 'assigned' && cap('can_start_delivery'))
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _start,
                          icon: const Icon(Icons.local_shipping_outlined),
                          label: const Text('Start delivery'),
                        ),
                      ),
                    if (_assignment.status == 'out_for_delivery' && cap('can_complete_delivery')) ...[
                      if (_arrived)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.where_to_vote_rounded, size: 16, color: AppTheme.success),
                              SizedBox(width: 6),
                              Text('Arrived — ready to complete',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.success)),
                            ],
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _openPod,
                          style: _arrived
                              ? ElevatedButton.styleFrom(backgroundColor: AppTheme.success)
                              : null,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Complete with POD'),
                        ),
                      ),
                      if (cap('can_fail_delivery')) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _loading ? null : _fail,
                            child: const Text('Report failed'),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
