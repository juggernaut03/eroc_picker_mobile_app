/// Google Maps API key for native map tiles (optional).
/// Pass at build time: --dart-define=GOOGLE_MAPS_API_KEY=your_key
class MapsConfig {
  static const googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  static bool get hasGoogleKey => googleMapsApiKey.isNotEmpty;
}
