import 'dart:io';

import '../models/order_model.dart';
import '../models/notification_model.dart';
import 'api_service.dart';

class RiderService {
  static Future<List<DeliveryAssignment>> getMyDeliveries({String? status}) async {
    final query = status != null ? '?status=$status' : '';
    final res = await ApiService.get('/rider/deliveries$query');
    final list = res['data'] as List? ?? [];
    return list.map((e) => DeliveryAssignment.fromJson(e)).toList();
  }

  static Future<({DeliveryAssignment assignment, Order? order})> getDeliveryDetail(
    int ordersIdorders,
  ) async {
    final res = await ApiService.get('/rider/deliveries/$ordersIdorders');
    final data = res['data'] as Map<String, dynamic>;
    return (
      assignment: DeliveryAssignment.fromJson(data['assignment']),
      order: data['order'] != null ? Order.fromJson(data['order']) : null,
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
  }) async {
    await ApiService.post('/rider/deliveries/$assignmentId/complete', {
      'photo_urls': photoUrls,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (recipientName != null && recipientName.isNotEmpty) 'recipient_name': recipientName,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
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
}
