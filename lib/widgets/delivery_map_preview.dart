import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../utils/app_theme.dart';

/// In-app map preview using OpenStreetMap tiles (flutter_map).
/// Optional [polyline] from OSRM routing (list of `{lat, lng}` maps or LatLng).
class DeliveryMapPreview extends StatelessWidget {
  final String? latitude;
  final String? longitude;
  final double height;
  final List<LatLng>? polyline;

  const DeliveryMapPreview({
    super.key,
    this.latitude,
    this.longitude,
    this.height = 180,
    this.polyline,
  });

  factory DeliveryMapPreview.fromPolylineJson(
    String? latitude,
    String? longitude,
    List<dynamic>? polylineJson, {
    double height = 180,
  }) {
    final pts = (polylineJson ?? [])
        .map((p) {
          final m = p as Map<String, dynamic>;
          final lat = (m['lat'] as num?)?.toDouble();
          final lng = (m['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) return null;
          return LatLng(lat, lng);
        })
        .whereType<LatLng>()
        .toList();
    final dest = pts.isNotEmpty ? pts.last : null;
    return DeliveryMapPreview(
      latitude: latitude ?? dest?.latitude.toString(),
      longitude: longitude ?? dest?.longitude.toString(),
      height: height,
      polyline: pts.isEmpty ? null : pts,
    );
  }

  LatLng? get _destination {
    final lat = double.tryParse(latitude ?? '');
    final lng = double.tryParse(longitude ?? '');
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final dest = _destination;
    if (dest == null) {
      return Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Text('No coordinates', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    final points = polyline ?? [dest];
    final bounds = LatLngBounds.fromPoints(points);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(24)),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.shalvi.picker_app',
            ),
            if (polyline != null && polyline!.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: polyline!,
                    color: AppTheme.primary,
                    strokeWidth: 4,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: dest,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on, color: Colors.red, size: 36),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
