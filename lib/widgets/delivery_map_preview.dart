import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart';

import '../config/maps_config.dart';
import '../utils/app_theme.dart';

/// Map preview with Google Maps SDK when API key is set, otherwise OpenStreetMap.
/// Optional [polyline] from Google Directions (list of `{lat, lng}` maps or LatLng).
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

    if (MapsConfig.hasGoogleKey) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: height,
          child: gmaps.GoogleMap(
            initialCameraPosition: gmaps.CameraPosition(target: gmaps.LatLng(dest.latitude, dest.longitude), zoom: 14),
            markers: {
              gmaps.Marker(
                markerId: const gmaps.MarkerId('dest'),
                position: gmaps.LatLng(dest.latitude, dest.longitude),
              ),
            },
            polylines: polyline == null || polyline!.isEmpty
                ? {}
                : {
                    gmaps.Polyline(
                      polylineId: const gmaps.PolylineId('route'),
                      color: AppTheme.primary,
                      width: 4,
                      points: polyline!.map((p) => gmaps.LatLng(p.latitude, p.longitude)).toList(),
                    ),
                  },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
        ),
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
