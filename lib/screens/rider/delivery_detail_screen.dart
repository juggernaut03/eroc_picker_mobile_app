import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/order_model.dart';
import '../../models/item_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/rider_location_tracker.dart';
import '../../services/rider_service.dart';
import '../../utils/address_utils.dart';
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

/// Geofence radius (metres): the rider must be within this distance of the
/// customer location before "Complete with POD" unlocks. Single source of truth.
const double kGeofenceRadiusMeters = 200;

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  bool _loading = false;
  bool _otpRequired = false;
  bool _arrived = false;
  late DeliveryAssignment _assignment;
  Order? _order;
  List<OrderItem> _items = const [];

  // --- Geofence state ---
  double? _distanceToDest; // metres to customer; null = unknown/no coords
  double _gpsAccuracy = 0; // metres; larger = less reliable fix
  bool _overridden = false; // rider manually bypassed the fence

  /// Order has usable destination coordinates to fence against.
  bool get _hasDest =>
      parseDeliveryLatLng(_order?.latitude, _order?.longitude) != null;

  /// GPS fix is too coarse to trust the fence (accuracy worse than the radius).
  bool get _gpsUnreliable =>
      _gpsAccuracy > 0 && _gpsAccuracy > kGeofenceRadiusMeters;

  /// Whether "Complete with POD" is allowed right now.
  /// Fail-open when we can't fence (no coords / unreliable GPS) or on override.
  bool get _canComplete {
    if (_overridden) return true;
    if (!_hasDest) return true; // can't fence an unknown location
    if (_gpsUnreliable) return true; // don't trap on GPS drift
    if (_distanceToDest == null) return false; // have coords, no fix yet → wait
    return _distanceToDest! <= kGeofenceRadiusMeters;
  }

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
        _items = res.items;
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

  void _onLeftFence() {
    if (!mounted) return;
    setState(() => _arrived = false);
  }

  void _onDistanceUpdate(double? meters, double accuracy) {
    if (!mounted) return;
    setState(() {
      _distanceToDest = meters;
      _gpsAccuracy = accuracy;
    });
  }

  void _requestOverride() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete anyway?'),
        content: Text(
          _distanceToDest != null
              ? "You're about ${_distanceToDest!.round()} m from the saved "
                  "customer location. Complete only if you're actually at the "
                  "delivery address — this override is recorded."
              : "We couldn't confirm your distance to the customer. Complete "
                  "only if you're at the delivery address — this override is "
                  "recorded.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("I'm here"),
          ),
        ],
      ),
    );
    if (ok == true && mounted) setState(() => _overridden = true);
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
              arriveRadiusMeters: kGeofenceRadiusMeters,
              onArrived: _onArrived,
              onLeft: _onLeftFence,
              onDistanceUpdate: _onDistanceUpdate,
            );
          }),
          // Navigate is only relevant once the rider has started the delivery
          // (out_for_delivery). Before "Start delivery" it stays hidden.
          if (_assignment.status == 'out_for_delivery') ...[
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
          ],
          const SizedBox(height: 12),
          if (order?.deliveryDetails != null)
            _DeliveryAddressCard(DeliveryAddress.parse(order!.deliveryDetails)),
          if (order?.deliveryDate != null) ...[
            const SizedBox(height: 8),
            Text('Delivery date: ${order!.deliveryDate}', style: const TextStyle(color: AppTheme.textSecondary)),
          ],
          if (order?.deliverySlot != null) ...[
            const SizedBox(height: 4),
            Text('Slot: ${order!.deliverySlot}', style: const TextStyle(color: AppTheme.textSecondary)),
          ],
          const SizedBox(height: 16),
          _ItemsSection(items: _items, totalItems: order?.totalItems),
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
                      _GeofenceStatus(
                        canComplete: _canComplete,
                        distance: _distanceToDest,
                        radius: kGeofenceRadiusMeters,
                        hasDest: _hasDest,
                        gpsUnreliable: _gpsUnreliable,
                        overridden: _overridden,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: (_loading || !_canComplete) ? null : _openPod,
                          style: _canComplete
                              ? ElevatedButton.styleFrom(backgroundColor: AppTheme.success)
                              : null,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Complete with POD'),
                        ),
                      ),
                      // Escape hatch: a bad customer pin or GPS glitch must never
                      // permanently block a real delivery. Override is recorded.
                      if (!_canComplete)
                        Align(
                          alignment: Alignment.center,
                          child: TextButton(
                            onPressed: _loading ? null : _requestOverride,
                            child: const Text("Can't unlock? I'm here"),
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

/// Live geofence status strip shown above "Complete with POD". Tells the rider
/// whether they're inside the delivery boundary and, if not, how far off.
class _GeofenceStatus extends StatelessWidget {
  final bool canComplete;
  final double? distance;
  final double radius;
  final bool hasDest;
  final bool gpsUnreliable;
  final bool overridden;

  const _GeofenceStatus({
    required this.canComplete,
    required this.distance,
    required this.radius,
    required this.hasDest,
    required this.gpsUnreliable,
    required this.overridden,
  });

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final Color color;
    late final String text;

    if (overridden) {
      icon = Icons.info_outline;
      color = AppTheme.textSecondary;
      text = 'Location override applied — this will be recorded.';
    } else if (!hasDest) {
      icon = Icons.location_off_outlined;
      color = AppTheme.textSecondary;
      text = 'No saved customer location — geofence skipped.';
    } else if (gpsUnreliable) {
      icon = Icons.gps_off_outlined;
      color = AppTheme.warning;
      text = 'Weak GPS signal — distance check skipped.';
    } else if (distance == null) {
      icon = Icons.gps_not_fixed;
      color = AppTheme.textSecondary;
      text = 'Getting your location…';
    } else if (canComplete) {
      icon = Icons.where_to_vote_rounded;
      color = AppTheme.success;
      text = "You're at the location — ready to complete.";
    } else {
      icon = Icons.explore_outlined;
      color = AppTheme.warning;
      text =
          'Move within ${radius.round()} m to complete · currently ${_fmt(distance!)} away.';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ],
    );
  }

  String _fmt(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.round()} m';
}

/// Order line-items the rider is carrying, shown read-only (name, pack size,
/// quantity, price). Backend sends these on the delivery-detail response.
class _ItemsSection extends StatelessWidget {
  final List<OrderItem> items;
  final int? totalItems;
  const _ItemsSection({required this.items, this.totalItems});

  String _money(double? v) =>
      v == null ? '' : '₹${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final count = items.isNotEmpty ? items.length : (totalItems ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 18, color: AppTheme.textPrimary),
            const SizedBox(width: 6),
            const Text(
              'Items',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Item details not available for this order.',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++)
                  _ItemRow(item: items[i], divider: i < items.length - 1, money: _money),
              ],
            ),
          ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  final OrderItem item;
  final bool divider;
  final String Function(double?) money;
  const _ItemRow({required this.item, required this.divider, required this.money});

  @override
  Widget build(BuildContext context) {
    final price = item.productOfferPrice ?? item.productMrp;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: divider
            ? const Border(bottom: BorderSide(color: AppTheme.border))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quantity chip
          Container(
            margin: const EdgeInsets.only(right: 10, top: 1),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '×${item.orderedQuantity}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName ?? 'Item',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (item.packSize != null && item.packSize!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      item.packSize!,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ),
              ],
            ),
          ),
          if (price != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 1),
              child: Text(
                money(price),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Labelled delivery address card for the detail screen. Parses the flat
/// `delivery_details` string into customer / address / phone rows, with a
/// tappable call action on the phone number.
class _DeliveryAddressCard extends StatelessWidget {
  final DeliveryAddress addr;
  const _DeliveryAddressCard(this.addr);

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: addr.phone);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (addr.isEmpty) {
      return Text(
        addr.raw.isEmpty ? 'No address provided' : addr.raw,
        style: const TextStyle(fontSize: 15),
      );
    }

    final line = addr.fullAddress;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DELIVER TO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          if (addr.name != null && addr.name!.isNotEmpty)
            Text(
              addr.name!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          if (line.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2, right: 6),
                    child: Icon(Icons.location_on_outlined,
                        size: 16, color: AppTheme.textMuted),
                  ),
                  Expanded(
                    child: Text(
                      line,
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          if (addr.phone != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InkWell(
                onTap: _call,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 16, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        addr.phone!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Tap to call',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
