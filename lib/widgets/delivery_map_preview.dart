import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../utils/app_theme.dart';
import '../utils/geo_utils.dart';

/// In-app map preview (OpenStreetMap / Carto tiles via flutter_map).
class DeliveryMapPreview extends StatefulWidget {
  final String? latitude;
  final String? longitude;
  final double height;
  final List<LatLng>? polyline;

  const DeliveryMapPreview({
    super.key,
    this.latitude,
    this.longitude,
    this.height = 200,
    this.polyline,
  });

  factory DeliveryMapPreview.fromPolylineJson(
    String? latitude,
    String? longitude,
    List<dynamic>? polylineJson, {
    double height = 200,
  }) {
    final pts = (polylineJson ?? [])
        .map((p) {
          final m = p as Map<String, dynamic>;
          final lat = (m['lat'] as num?)?.toDouble();
          final lng = (m['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) return null;
          return parseDeliveryLatLng(lat.toString(), lng.toString()) ?? LatLng(lat, lng);
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

  LatLng? get destination => parseDeliveryLatLng(latitude, longitude);

  @override
  State<DeliveryMapPreview> createState() => _DeliveryMapPreviewState();
}

class _DeliveryMapPreviewState extends State<DeliveryMapPreview> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
  }

  @override
  void didUpdateWidget(covariant DeliveryMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.polyline != widget.polyline) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
    }
  }

  void _fitCamera() {
    final dest = widget.destination;
    if (dest == null || !mounted) return;

    final route = widget.polyline;
    if (route != null && route.length > 1) {
      final bounds = LatLngBounds.fromPoints(route);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(36)),
      );
      return;
    }

    _mapController.move(dest, 16);
  }

  @override
  Widget build(BuildContext context) {
    final dest = widget.destination;
    if (dest == null) {
      return Container(
        height: widget.height,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined, color: AppTheme.textSecondary, size: 28),
            SizedBox(height: 8),
            Text(
              'No delivery coordinates on this order',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: dest,
                initialZoom: 16,
                minZoom: 4,
                maxZoom: 19,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.shalvi.picker_app',
                  retinaMode: RetinaMode.isHighDensity(context),
                ),
                if (widget.polyline != null && widget.polyline!.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: widget.polyline!,
                        color: AppTheme.primary,
                        strokeWidth: 5,
                      ),
                    ],
                  ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: dest,
                      radius: 28,
                      useRadiusInMeter: false,
                      color: AppTheme.primary.withValues(alpha: 0.18),
                      borderColor: AppTheme.primary.withValues(alpha: 0.55),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: dest,
                      width: 44,
                      height: 44,
                      alignment: Alignment.bottomCenter,
                      child: const Icon(
                        Icons.location_on,
                        color: Color(0xFFE53935),
                        size: 44,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    '${dest.latitude.toStringAsFixed(5)}, ${dest.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontFeatures: []),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
