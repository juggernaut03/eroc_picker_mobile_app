import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../utils/app_theme.dart';

/// A stop to show on the live navigation map.
class NavStop {
  final LatLng point;
  final int? sequence;
  final bool isCurrent;
  final bool isDone;

  const NavStop({
    required this.point,
    this.sequence,
    this.isCurrent = false,
    this.isDone = false,
  });
}

/// Live in-app map (free OSM/Carto tiles) showing the rider's own moving
/// GPS position relative to one or more delivery stops. Streams the device
/// location, draws a heading-aware "you" dot, and reports proximity so the
/// caller can surface an "Arrived" affordance. No API key required.
class LiveNavMap extends StatefulWidget {
  final List<NavStop> stops;
  final double height;

  /// Fired (once per entry) when the rider gets within [arriveRadiusMeters]
  /// of the current stop. Use to prompt "Arrived — complete delivery?".
  final VoidCallback? onArrived;

  /// Fired once when the rider leaves the fence again (past the re-arm band),
  /// so a geofence gate can re-lock itself.
  final VoidCallback? onLeft;

  /// Fired on every GPS fix with the current distance to the target (metres)
  /// and the fix accuracy (metres). Lets the parent drive a live distance UI /
  /// geofence gate. Distance is null when the target has no coordinates.
  final void Function(double? meters, double accuracy)? onDistanceUpdate;

  final double arriveRadiusMeters;

  const LiveNavMap({
    super.key,
    required this.stops,
    this.height = 280,
    this.onArrived,
    this.onLeft,
    this.onDistanceUpdate,
    this.arriveRadiusMeters = 60,
  });

  @override
  State<LiveNavMap> createState() => _LiveNavMapState();
}

class _LiveNavMapState extends State<LiveNavMap> {
  final MapController _map = MapController();
  StreamSubscription<Position>? _posSub;
  LatLng? _me;
  double _heading = 0;
  bool _following = true;
  bool _arrivedFired = false;
  final Distance _distance = const Distance();

  NavStop? get _target {
    for (final s in widget.stops) {
      if (s.isCurrent) return s;
    }
    return widget.stops.isNotEmpty ? widget.stops.first : null;
  }

  @override
  void initState() {
    super.initState();
    _startLocation();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _startLocation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return;
    }
    try {
      final cur = await Geolocator.getCurrentPosition();
      _onPosition(cur);
    } catch (_) {}
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
      ),
    ).listen(_onPosition, onError: (_) {});
  }

  void _onPosition(Position pos) {
    if (!mounted) return;
    final me = LatLng(pos.latitude, pos.longitude);
    setState(() {
      _me = me;
      if (pos.heading >= 0) _heading = pos.heading;
    });

    final target = _target;
    if (target != null) {
      final meters = _distance(me, target.point);
      widget.onDistanceUpdate?.call(meters, pos.accuracy);
      if (!_arrivedFired && meters <= widget.arriveRadiusMeters) {
        _arrivedFired = true;
        widget.onArrived?.call();
      } else if (_arrivedFired && meters > widget.arriveRadiusMeters * 1.6) {
        _arrivedFired = false; // re-arm if they leave and return
        widget.onLeft?.call();
      }
    } else {
      widget.onDistanceUpdate?.call(null, pos.accuracy);
    }

    if (_following) _fit();
  }

  void _fit() {
    final me = _me;
    final target = _target?.point;
    if (me == null) return;
    if (target == null) {
      _map.move(me, 16);
      return;
    }
    final bounds = LatLngBounds.fromPoints([me, target]);
    _map.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(56)),
    );
  }

  double? _metersToTarget() {
    final me = _me;
    final t = _target?.point;
    if (me == null || t == null) return null;
    return _distance(me, t);
  }

  String _fmtDistance(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.round()} m';

  @override
  Widget build(BuildContext context) {
    final stops = widget.stops;
    final initialCenter = _me ?? _target?.point ?? const LatLng(20.5937, 78.9629);
    final meters = _metersToTarget();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: 15,
                minZoom: 4,
                maxZoom: 19,
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture && _following) setState(() => _following = false);
                },
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.drag |
                      InteractiveFlag.doubleTapZoom |
                      InteractiveFlag.flingAnimation,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.shalvi.picker_app',
                  retinaMode: RetinaMode.isHighDensity(context),
                ),
                if (_me != null && _target != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [_me!, _target!.point],
                        color: AppTheme.primary.withValues(alpha: 0.5),
                        strokeWidth: 4,
                        pattern: const StrokePattern.dotted(),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    ...stops.map(_stopMarker),
                    if (_me != null)
                      Marker(
                        point: _me!,
                        width: 46,
                        height: 46,
                        child: _MeDot(heading: _heading),
                      ),
                  ],
                ),
              ],
            ),

            // Distance / ETA chip
            if (meters != null)
              Positioned(
                left: 10,
                top: 10,
                child: _InfoChip(
                  icon: Icons.straighten_rounded,
                  text: '${_fmtDistance(meters)} to stop',
                ),
              ),

            // Recenter button
            Positioned(
              right: 10,
              bottom: 10,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 3,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    setState(() => _following = true);
                    _fit();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      _following ? Icons.my_location_rounded : Icons.location_searching_rounded,
                      color: _following ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Marker _stopMarker(NavStop s) {
    final Color c = s.isDone
        ? AppTheme.success
        : s.isCurrent
            ? AppTheme.primary
            : AppTheme.textSecondary;
    return Marker(
      point: s.point,
      width: 40,
      height: 48,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
            alignment: Alignment.center,
            child: s.isDone
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    s.sequence?.toString() ?? '•',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
          ),
          CustomPaint(size: const Size(12, 8), painter: _PinTail(c)),
        ],
      ),
    );
  }
}

/// The rider's own position — a heading-aware "you are here" dot.
class _MeDot extends StatelessWidget {
  final double heading;
  const _MeDot({required this.heading});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: heading * 3.1415926535 / 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
          ),
          // Heading cone
          Positioned(
            top: 2,
            child: Icon(Icons.navigation_rounded,
                size: 18, color: AppTheme.primary.withValues(alpha: 0.9)),
          ),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _PinTail extends CustomPainter {
  final Color color;
  _PinTail(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinTail old) => old.color != color;
}
