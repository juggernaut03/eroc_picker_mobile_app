import 'dart:io';

import '../models/order_model.dart';
import '../models/notification_model.dart';
import '../models/delivery_route_model.dart';
import 'api_service.dart';

class RiderService {
  static Future<List<DeliveryAssignment>> getMyDeliveries({String? status}) async {
    final query = status != null ? '?status=$status' : '';
    final res = await ApiService.get('/rider/deliveries$query');
    final list = res['data'] as List? ?? [];
    return list.map((e) => DeliveryAssignment.fromJson(e)).toList();
  }

  static Future<({DeliveryAssignment assignment, Order? order, bool otpRequired})> getDeliveryDetail(
    int ordersIdorders,
  ) async {
    final res = await ApiService.get('/rider/deliveries/$ordersIdorders');
    final data = res['data'] as Map<String, dynamic>;
    return (
      assignment: DeliveryAssignment.fromJson(data['assignment']),
      order: data['order'] != null ? Order.fromJson(data['order']) : null,
      otpRequired: data['otp_required'] == true,
    );
  }

  static Future<void> startDelivery(String assignmentId) async {
    await ApiService.post('/rider/deliveries/$assignmentId/start', {});
  }

  static Future<void> completeDelivery(
    String assignmentId, {
    required List<String> photoUrls,
    String? notes,
    String? recipientName,
    String? latitude,
    String? longitude,
    String? signatureUrl,
    String? otp,
  }) async {
    await ApiService.post('/rider/deliveries/$assignmentId/complete', {
      'photo_urls': photoUrls,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (recipientName != null && recipientName.isNotEmpty) 'recipient_name': recipientName,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (signatureUrl != null && signatureUrl.isNotEmpty) 'signature_url': signatureUrl,
      if (otp != null && otp.isNotEmpty) 'otp': otp,
    });
  }

  static Future<void> failDelivery(String assignmentId, String reason) async {
    await ApiService.post('/rider/deliveries/$assignmentId/fail', {'reason': reason});
  }

  static Future<String> uploadPodPhoto(File file) async {
    final res = await ApiService.postMultipart('/rider/upload-pod', 'photo', file);
    return (res['data'] as Map)['url'] as String;
  }

  static Future<void> setAvailability(bool online) async {
    await ApiService.patch('/rider/me/availability', {'online': online});
  }

  static Future<void> updateLocation(double latitude, double longitude) async {
    await ApiService.patch('/rider/me/location', {
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  static Future<({List<NotificationItem> items, int unreadCount})> getNotifications({
    bool unreadOnly = false,
  }) async {
    final query = unreadOnly ? '?unread_only=true' : '';
    final res = await ApiService.get('/rider/notifications$query');
    final list = (res['data'] as List? ?? [])
        .map((e) => NotificationItem.fromJson(e))
        .toList();
    return (items: list, unreadCount: res['unread_count'] as int? ?? 0);
  }

  static Future<void> markNotificationRead(String id) async {
    await ApiService.patch('/rider/notifications/$id/read', {});
  }

  static Future<DeliveryRoute?> getActiveRoute() async {
    final res = await ApiService.get('/rider/routes/active');
    final data = res['data'];
    if (data == null) return null;
    return DeliveryRoute.fromJson(data as Map<String, dynamic>);
  }

  static Future<DeliveryRoute> getRoute(String routeId) async {
    final res = await ApiService.get('/rider/routes/$routeId');
    return DeliveryRoute.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Builds (or returns the existing) optimized route for all the rider's
  /// pending deliveries, sequenced from [latitude]/[longitude] (the rider's
  /// live position) when provided, else from the store origin.
  static Future<DeliveryRoute> startMyRoute({double? latitude, double? longitude}) async {
    final res = await ApiService.post('/rider/routes/start', {
      if (latitude != null && longitude != null) 'latitude': latitude,
      if (latitude != null && longitude != null) 'longitude': longitude,
    });
    return DeliveryRoute.fromJson(res['data'] as Map<String, dynamic>);
  }
}
