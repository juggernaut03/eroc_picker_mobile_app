import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/delivery_route_model.dart';
import '../../models/order_model.dart';
import '../../services/manager_service.dart';
import '../../utils/app_theme.dart';

class CreateRouteScreen extends StatefulWidget {
  const CreateRouteScreen({super.key});

  @override
  State<CreateRouteScreen> createState() => _CreateRouteScreenState();
}

class _CreateRouteScreenState extends State<CreateRouteScreen> {
  bool _loading = true;
  bool _saving = false;
  List<Order> _readyOrders = [];
  final Set<int> _selected = {};
  List<int> _stopOrder = [];
  List<AssignedUser> _riders = [];
  String? _riderId;
  RouteSuggestion? _suggestion;

  static const _maxStops = 4;
  static const _minStops = 2;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ManagerService.getAllOrders(status: 'completed', deliveryStatus: 'ready_for_delivery'),
        ManagerService.getRiders(),
      ]);
      if (!mounted) return;
      setState(() {
        _readyOrders = results[0] as List<Order>;
        _riders = results[1] as List<AssignedUser>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _toggleOrder(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
        _stopOrder.remove(id);
      } else if (_selected.length < _maxStops) {
        _selected.add(id);
        _stopOrder.add(id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Maximum $_maxStops orders per route')),
        );
      }
      _suggestion = null;
    });
  }

  Future<void> _suggestOrder() async {
    if (_selected.length < _minStops) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Select at least $_minStops orders')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final suggestion = await ManagerService.suggestRouteOrder(
        ordersIdorders: _selected.toList(),
        stopOrder: _stopOrder.isNotEmpty ? _stopOrder : null,
      );
      if (!mounted) return;
      setState(() {
        _suggestion = suggestion;
        _stopOrder = List<int>.from(suggestion.stopOrder);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createRoute() async {
    if (_selected.length < _minStops) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Select at least $_minStops orders')),
      );
      return;
    }
    if (_riderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a rider')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ManagerService.createDeliveryRoute(
        ordersIdorders: _stopOrder.isNotEmpty ? _stopOrder : _selected.toList(),
        riderId: _riderId!,
        stopOrder: _stopOrder.isNotEmpty ? _stopOrder : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery route created')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _previewMaps() async {
    final url = _suggestion?.mapsUrl;
    if (url == null || url.isEmpty) {
      await _suggestOrder();
      return;
    }
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps')),
      );
    }
  }

  Order? _orderById(int id) {
    for (final o in _readyOrders) {
      if (o.ordersIdorders == id) return o;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Create Delivery Route', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_suggestion != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, size: 18, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '~${_suggestion!.estimatedDurationMin} min · ${_suggestion!.estimatedDistanceKm.toStringAsFixed(1)} km',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                        TextButton(onPressed: _previewMaps, child: const Text('Preview')),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        'Select $_minStops–$_maxStops ready orders (${_selected.length}/$_maxStops)',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _selected.length >= _minStops && !_saving ? _suggestOrder : null,
                        icon: const Icon(Icons.route, size: 18),
                        label: const Text('Optimize'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _readyOrders.isEmpty
                      ? const Center(
                          child: Text('No orders ready for delivery',
                              style: TextStyle(color: AppTheme.textSecondary)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _readyOrders.length,
                          itemBuilder: (ctx, i) {
                            final o = _readyOrders[i];
                            final checked = _selected.contains(o.ordersIdorders);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: CheckboxListTile(
                                value: checked,
                                onChanged: (_) => _toggleOrder(o.ordersIdorders),
                                title: Text('#${o.ordersIdorders}',
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text(
                                  [
                                    o.storeCode,
                                    if (o.deliverySlot != null) o.deliverySlot!,
                                    if (o.deliveryDetails != null) o.deliveryDetails!,
                                  ].join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (_stopOrder.isNotEmpty) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Stop order', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    ),
                  ),
                  SizedBox(
                    height: 140,
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _stopOrder.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = _stopOrder.removeAt(oldIndex);
                          _stopOrder.insert(newIndex, item);
                          _suggestion = null;
                        });
                      },
                      itemBuilder: (ctx, i) {
                        final id = _stopOrder[i];
                        final o = _orderById(id);
                        return ListTile(
                          key: ValueKey(id),
                          leading: CircleAvatar(
                            radius: 14,
                            child: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
                          ),
                          title: Text('Order #$id'),
                          subtitle: o?.deliveryDetails != null ? Text(o!.deliveryDetails!) : null,
                          trailing: const Icon(Icons.drag_handle),
                        );
                      },
                    ),
                  ),
                ],
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _riderId,
                        decoration: const InputDecoration(
                          labelText: 'Assign rider',
                          border: OutlineInputBorder(),
                        ),
                        items: _riders
                            .map((r) => DropdownMenuItem(
                                  value: r.id,
                                  child: Text(r.name),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _riderId = v),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _saving ? null : _createRoute,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Create route', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
