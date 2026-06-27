/// OpenStreetMap links for external navigation (no API key required).
class OsmLinks {
  static String? pointUrl(double lat, double lng) {
    return 'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=16/$lat/$lng';
  }

  /// Single-leg or multi-point route via OSM directions (fossgis OSRM engine).
  static String directionsUrl({
    double? originLat,
    double? originLng,
    required double destLat,
    required double destLng,
  }) {
    final points = <String>[];
    if (originLat != null && originLng != null) {
      points.add('$originLat,$originLng');
    }
    points.add('$destLat,$destLng');
    final route = points.join(';');
    return 'https://www.openstreetmap.org/directions?engine=fossgis_osrm_car&route=$route';
  }
}
