import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_theme.dart';
import 'osm_links.dart';

/// A turn-by-turn navigation app the rider can hand off to.
enum NavApp { googleMaps, appleMaps, osmWeb }

extension NavAppMeta on NavApp {
  String get label => switch (this) {
        NavApp.googleMaps => 'Google Maps',
        NavApp.appleMaps => 'Apple Maps',
        NavApp.osmWeb => 'OpenStreetMap (web)',
      };

  String get subtitle => switch (this) {
        NavApp.googleMaps => 'Voice turn-by-turn & live traffic',
        NavApp.appleMaps => 'Built-in iPhone navigation',
        NavApp.osmWeb => 'Opens in browser — no voice guidance',
      };

  IconData get icon => switch (this) {
        NavApp.googleMaps => Icons.navigation_rounded,
        NavApp.appleMaps => Icons.map_rounded,
        NavApp.osmWeb => Icons.public_rounded,
      };

  Color get color => switch (this) {
        NavApp.googleMaps => const Color(0xFF1A73E8),
        NavApp.appleMaps => const Color(0xFF34A853),
        NavApp.osmWeb => AppTheme.textSecondary,
      };
}

/// Launches external turn-by-turn navigation, preferring the best app
/// installed on the rider's phone. 100% free, no API key required.
///
/// Android: `google.navigation:` (Google Maps turn-by-turn) → `geo:` → OSM web.
/// iOS: Google Maps (`comgooglemaps://`) → Apple Maps → OSM web.
class NavLauncher {
  NavLauncher._();

  /// Which apps to even consider, in priority order. OSM web is always last.
  static List<NavApp> _candidatesFor(TargetPlatform platform) {
    if (platform == TargetPlatform.iOS) {
      return const [NavApp.googleMaps, NavApp.appleMaps, NavApp.osmWeb];
    }
    // Android & everything else.
    return const [NavApp.googleMaps, NavApp.osmWeb];
  }

  /// Returns the apps actually installed/usable on this device.
  static Future<List<NavApp>> availableApps() async {
    final platform = defaultTargetPlatform;
    final out = <NavApp>[];
    for (final app in _candidatesFor(platform)) {
      if (app == NavApp.osmWeb) {
        out.add(app); // always available — web fallback
        continue;
      }
      final probe = _probeUri(app, 0, 0);
      if (probe != null && await canLaunchUrl(probe)) out.add(app);
    }
    return out;
  }

  /// Drives the rider to [destLat],[destLng]. If more than one nav app is
  /// available it shows a quick picker; otherwise it launches directly.
  /// Returns false (and shows a snackbar) only if nothing could be opened.
  static Future<bool> navigateTo(
    BuildContext context, {
    required double destLat,
    required double destLng,
    String? label,
  }) async {
    final apps = await availableApps();
    if (!context.mounted) return false;

    NavApp? choice;
    final real = apps.where((a) => a != NavApp.osmWeb).toList();
    if (real.length <= 1) {
      // Zero or one real nav app: just go, no picker noise.
      choice = apps.first;
    } else {
      choice = await _showPicker(context, apps);
      if (choice == null) return false; // dismissed
    }

    final ok = await _launch(choice, destLat: destLat, destLng: destLng, label: label);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open a navigation app')),
      );
    }
    return ok;
  }

  static Future<bool> _launch(
    NavApp app, {
    required double destLat,
    required double destLng,
    String? label,
  }) async {
    final uris = _launchUris(app, destLat, destLng, label);
    for (final uri in uris) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return true;
      } catch (_) {/* try next */}
    }
    return false;
  }

  /// A lightweight URI used only to test installation (canLaunchUrl).
  static Uri? _probeUri(NavApp app, double lat, double lng) {
    switch (app) {
      case NavApp.googleMaps:
        return Platform.isIOS
            ? Uri.parse('comgooglemaps://')
            : Uri.parse('google.navigation:q=$lat,$lng');
      case NavApp.appleMaps:
        return Uri.parse('maps://');
      case NavApp.osmWeb:
        return null;
    }
  }

  /// Real launch URIs, in fallback order, for an actual destination.
  static List<Uri> _launchUris(NavApp app, double lat, double lng, String? label) {
    final q = '$lat,$lng';
    final name = label != null ? Uri.encodeComponent(label) : null;
    switch (app) {
      case NavApp.googleMaps:
        if (Platform.isIOS) {
          return [
            Uri.parse('comgooglemaps://?daddr=$q&directionsmode=driving'),
            Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$q&travelmode=driving'),
          ];
        }
        return [
          Uri.parse('google.navigation:q=$q&mode=d'),
          Uri.parse('geo:$lat,$lng?q=$q${name != null ? '($name)' : ''}'),
          Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$q&travelmode=driving'),
        ];
      case NavApp.appleMaps:
        return [Uri.parse('maps://?daddr=$q&dirflg=d')];
      case NavApp.osmWeb:
        return [
          Uri.parse(OsmLinks.directionsUrl(destLat: lat, destLng: lng)),
        ];
    }
  }

  static Future<NavApp?> _showPicker(BuildContext context, List<NavApp> apps) {
    return showModalBottomSheet<NavApp>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Navigate with',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ),
            ...apps.map(
              (a) => ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: a.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(a.icon, color: a.color),
                ),
                title: Text(a.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(a.subtitle, style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(ctx, a),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
