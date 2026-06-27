import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/rider_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/status_badge.dart';

class DeliveryDetailScreen extends StatefulWidget {
  final DeliveryAssignment assignment;

  const DeliveryDetailScreen({super.key, required this.assignment});

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  bool _loading = false;
  late DeliveryAssignment _assignment;
  Order? _order;
  final _notesCtrl = TextEditingController();
  final List<File> _photos = [];
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _assignment = widget.assignment;
    _order = widget.assignment.order;
    _load();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await RiderService.getDeliveryDetail(_assignment.ordersIdorders);
      if (!mounted) return;
      setState(() {
        _assignment = res.assignment;
        _order = res.order ?? _order;
      });
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
    final lat = _order?.latitude;
    final lng = _order?.longitude;
    if (lat == null || lng == null || lat.isEmpty || lng.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No delivery coordinates for this order')),
      );
      return;
    }
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition();
    } catch (_) {}

    final origin = pos != null ? '${pos.latitude},${pos.longitude}' : '';
    final dest = '$lat,$lng';
    final uri = Uri.parse(
      origin.isNotEmpty
          ? 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$dest&travelmode=driving'
          : 'https://www.google.com/maps/dir/?api=1&destination=$dest&travelmode=driving',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps')),
        );
      }
    }
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

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 75);
    if (file != null && mounted) setState(() => _photos.add(File(file.path)));
  }

  Future<void> _complete() async {
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one delivery photo'), backgroundColor: AppTheme.error),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final urls = <String>[];
      for (final f in _photos) {
        urls.add(await RiderService.uploadPodPhoto(f));
      }
      String? lat;
      String? lng;
      try {
        final pos = await Geolocator.getCurrentPosition();
        lat = pos.latitude.toString();
        lng = pos.longitude.toString();
      } catch (_) {}

      await RiderService.completeDelivery(
        _assignment.id,
        photoUrls: urls,
        notes: _notesCtrl.text.trim(),
        latitude: lat,
        longitude: lng,
      );
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
        actions: [if (_loading) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))],
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
          const SizedBox(height: 16),
          if (order?.deliveryDetails != null)
            Text(order!.deliveryDetails!, style: const TextStyle(fontSize: 15)),
          if (order?.deliveryDate != null) ...[
            const SizedBox(height: 8),
            Text('Delivery date: ${order!.deliveryDate}', style: const TextStyle(color: AppTheme.textSecondary)),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openMaps,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Open in Google Maps'),
          ),
          if (_assignment.status == 'out_for_delivery' && cap('can_complete_delivery')) ...[
            const SizedBox(height: 24),
            const Text('Proof of delivery', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._photos.map((f) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(f, width: 72, height: 72, fit: BoxFit.cover),
                    )),
                if (cap('can_upload_pod'))
                  OutlinedButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Add photo'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
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
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _complete,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Complete delivery'),
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
