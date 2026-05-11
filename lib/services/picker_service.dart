import '../models/order_model.dart';
import '../models/item_model.dart';
import '../models/notification_model.dart';
import 'api_service.dart';

class PickerService {
  static Future<List<Assignment>> getMyOrders({String? status}) async {
    final query = status != null ? '?status=$status' : '';
    final res = await ApiService.get('/picker/orders$query');
    final list = res['data'] as List? ?? [];
    return list.map((e) => Assignment.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> getOrderItems(
    int ordersIdorders, {
    int? page,
    int? limit,
    bool fetchStatus = true,
  }) async {
    final params = <String>[];
    if (page != null) params.add('page=$page');
    if (limit != null) params.add('limit=$limit');
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final res = await ApiService.get('/picker/orders/$ordersIdorders/items$query');
    final items = (res['data'] as List? ?? [])
        .map((e) => OrderItem.fromJson(e))
        .toList();
    // Fetching the live assignment status is expensive — skip on paginated calls.
    String liveStatus = 'assigned';
    if (fetchStatus) {
      try {
        final orders = await getMyOrders();
        final match = orders.where((a) => a.ordersIdorders == ordersIdorders);
        if (match.isNotEmpty) liveStatus = match.first.status;
      } catch (_) {}
    }
    return {
      'assignment_id': res['assignment_id'],
      'items': items,
      'status': liveStatus,
      'pagination': res['pagination'],
    };
  }

  /// Returns true if picking was started (or was already in_progress).
  static Future<bool> startPicking(int ordersIdorders) async {
    try {
      await ApiService.post('/picker/orders/$ordersIdorders/start', {});
      return true;
    } on ApiException catch (e) {
      // 404 means the assignment is already in_progress — treat as success.
      if (e.statusCode == 404) return true;
      rethrow;
    }
  }

  static Future<ItemPickerStatus> updateItemStatus({
    required String assignmentId,
    required String orderItemId,
    required String pickedStatus,
    required int pickedQuantity,
    String? remark,
  }) async {
    final res = await ApiService.put(
      '/picker/assignments/$assignmentId/items/$orderItemId',
      {
        'picked_status': pickedStatus,
        'picked_quantity': pickedQuantity,
        'remark': remark,
      },
    );
    return ItemPickerStatus.fromJson(res['data']);
  }

  static Future<void> completeOrder(int ordersIdorders) async {
    await ApiService.post('/picker/orders/$ordersIdorders/complete', {});
  }

  static Future<void> rejectOrder(int ordersIdorders, String reason) async {
    await ApiService.post(
      '/picker/orders/$ordersIdorders/reject',
      {'reason': reason},
    );
  }

  /// Returns the picker's notification feed and unread count.
  static Future<({List<NotificationItem> items, int unreadCount})>
      getNotifications({bool unreadOnly = false}) async {
    final query = unreadOnly ? '?unread_only=true' : '';
    final res = await ApiService.get('/picker/notifications$query');
    final list = (res['data'] as List? ?? [])
        .map((e) => NotificationItem.fromJson(e))
        .toList();
    return (items: list, unreadCount: (res['unread_count'] as int?) ?? 0);
  }

  static Future<void> markNotificationRead(String id) async {
    await ApiService.patch('/picker/notifications/$id/read', {});
  }

  static Future<void> markAllNotificationsRead() async {
    await ApiService.patch('/picker/notifications/all/read', {});
  }

  /// Find an assignment by order id from /picker/orders, so we can open the
  /// detail screen when the picker taps a notification.
  static Future<Assignment?> findAssignmentByOrderId(int ordersIdorders) async {
    final list = await getMyOrders();
    for (final a in list) {
      if (a.ordersIdorders == ordersIdorders) return a;
    }
    return null;
  }
}
