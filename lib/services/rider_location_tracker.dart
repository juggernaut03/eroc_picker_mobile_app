import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/order_model.dart';
import '../services/rider_service.dart';

/// Background-friendly GPS pings while the rider has active deliveries.
class RiderLocationTracker {
  RiderLocationTracker._();

  static StreamSubscription<Position>? _sub;
  static bool _active = false;

  static bool get isActive => _active;

  static Future<void> syncWithDeliveries(List<DeliveryAssignment> assignments) async {
    final needsTracking =
        assignments.any((a) => a.status == 'out_for_delivery');
    if (needsTracking) {
      await start();
    } else {
      stop();
    }
  }

  static Future<void> start() async {
    if (_sub != null) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    if (!kIsWeb && Platform.isAndroid) {
      final bg = await Geolocator.checkPermission();
      if (bg == LocationPermission.whileInUse) {
        await Geolocator.requestPermission();
      }
    }

    LocationSettings settings;
    if (!kIsWeb && Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 40,
        intervalDuration: const Duration(seconds: 45),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Retail Magic Delivery',
          notificationText: 'Sharing your location during active deliveries',
          enableWakeLock: true,
        ),
      );
    } else if (!kIsWeb && Platform.isIOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 40,
        activityType: ActivityType.automotiveNavigation,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 40,
      );
    }

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) => RiderService.updateLocation(pos.latitude, pos.longitude).catchError((_) {}),
      onError: (_) {},
    );
    _active = true;

    try {
      final pos = await Geolocator.getCurrentPosition();
      await RiderService.updateLocation(pos.latitude, pos.longitude);
    } catch (_) {}
  }

  static void stop() {
    _sub?.cancel();
    _sub = null;
    _active = false;
  }
}
