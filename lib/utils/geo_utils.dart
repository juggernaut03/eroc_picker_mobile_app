import 'package:latlong2/latlong.dart';

/// Parse order latitude/longitude strings into a map point.
/// Handles swapped lat/lng (common upstream bug) using valid ranges + India heuristic.
LatLng? parseDeliveryLatLng(String? latitude, String? longitude) {
  final a = double.tryParse(latitude?.trim() ?? '');
  final b = double.tryParse(longitude?.trim() ?? '');
  if (a == null || b == null) return null;

  if (_isValidLat(a) && _isValidLng(b)) return LatLng(a, b);
  if (_isValidLat(b) && _isValidLng(a)) return LatLng(b, a);

  // India: lat ~6–37, lng ~68–97 — often stored reversed
  if (_looksLikeIndiaLng(a) && _looksLikeIndiaLat(b)) return LatLng(b, a);
  if (_looksLikeIndiaLat(a) && _looksLikeIndiaLng(b)) return LatLng(a, b);

  return null;
}

bool _isValidLat(double v) => v >= -90 && v <= 90;
bool _isValidLng(double v) => v >= -180 && v <= 180;

bool _looksLikeIndiaLat(double v) => v >= 6 && v <= 37;
bool _looksLikeIndiaLng(double v) => v >= 68 && v <= 97;
