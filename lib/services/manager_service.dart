import '../models/order_model.dart';
import '../models/item_model.dart';
import '../models/notification_model.dart';
import '../models/delivery_route_model.dart';
import 'api_service.dart';

class ManagerService {
  static Future<List<Order>> getAllOrders({
    String? status,
    String? storeCode,
    String? deliveryStatus,
  }) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    if (storeCode != null) params['store_code'] = storeCode;
    if (deliveryStatus != null) params['delivery_status'] = deliveryStatus;
    final query = params.isNotEmpty
        ? '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}'
        : '';
    final res = await ApiService.get('/manager/orders$query');
    final list = res['data'] as List? ?? [];
    return list.map((e) => Order.fromJson(e)).toList();
  }

  /// Manager flags a completed order for the super admin to review.
  static Future<void> sendOrderToSuperAdmin(int ordersIdorders) async {
    await ApiService.post(
      '/manager/orders/$ordersIdorders/send-to-super-admin',
      {},
    );
  }

  static Future<List<AssignedUser>> getPickers() async {
    final res = await ApiService.get('/manager/pickers');
    final list = res['data'] as List? ?? [];
    return list.map((e) => AssignedUser.fromJson(e)).toList();
  }

  static Future<List<AssignedUser>> getRiders() async {
    final res = await ApiService.get('/manager/riders');
    final list = res['data'] as List? ?? [];
    return list.map((e) => AssignedUser.fromJson(e)).toList();
  }

  static Future<void> assignRider({
    required int ordersIdorders,
    required String riderId,
  }) async {
    await ApiService.post('/manager/orders/$ordersIdorders/assign-rider', {
      'rider_id': riderId,
    });
  }

  static Future<void> reassignRider({
    required int ordersIdorders,
    required String newRiderId,
  }) async {
    await ApiService.post('/manager/deliveries/reassign', {
      'orders_idorders': ordersIdorders,
      'new_rider_id': newRiderId,
    });
  }

  static Future<({AssignedUser rider, List<DeliveryAssignment> deliveries})> getRider(
    String riderId,
  ) async {
    final res = await ApiService.get('/manager/riders/$riderId');
    final data = res['data'] as Map<String, dynamic>;
    final deliveries = (data['deliveries'] as List? ?? [])
        .map((e) => DeliveryAssignment.fromJson(e as Map<String, dynamic>))
        .toList();
    return (
      rider: AssignedUser.fromJson(data['rider'] as Map<String, dynamic>),
      deliveries: deliveries,
    );
  }

  static Future<void> assignOrder({
    required int ordersIdorders,
    required String storeCode,
    required String projectCode,
  }) async {
    await ApiService.post('/manager/assign-order', {
      'orders_idorders': ordersIdorders,
      'store_code': storeCode,
      'project_code': projectCode,
    });
  }

  static Future<void> reassignOrder({
    required int ordersIdorders,
    required String newPickerId,
  }) async {
    await ApiService.post('/manager/reassign', {
      'orders_idorders': ordersIdorders,
      'new_picker_id': newPickerId,
    });
  }

  /// Fetch a single order by id. Uses the existing list endpoint and filters
  /// client-side — there's no dedicated backend route yet.
  static Future<Order?> getOrder(int ordersIdorders) async {
    final orders = await getAllOrders();
    for (final o in orders) {
      if (o.ordersIdorders == ordersIdorders) return o;
    }
    return null;
  }

  static Future<List<OrderItem>> getOrderItems(int ordersIdorders) async {
    final res = await ApiService.get('/manager/orders/$ordersIdorders/items');
    final list = res['data'] as List? ?? [];
    return list.map((e) => OrderItem.fromJson(e)).toList();
  }

  static Future<List<Remark>> getAllRemarks({String? storeCode}) async {
    final query = storeCode != null ? '?store_code=$storeCode' : '';
    final res = await ApiService.get('/manager/remarks$query');
    final list = res['data'] as List? ?? [];
    return list.map((e) => Remark.fromJson(e)).toList();
  }

  static Future<Escalation> createEscalation({
    required String assignmentId,
    required int ordersIdorders,
    required String storeCode,
    String? itemStatusId,
    String? itemName,
    required String remarkSummary,
  }) async {
    final res = await ApiService.post('/manager/escalations', {
      'assignment_id': assignmentId,
      'orders_idorders': ordersIdorders,
      'store_code': storeCode,
      if (itemStatusId != null) 'item_status_id': itemStatusId,
      if (itemName != null) 'item_name': itemName,
      'remark_summary': remarkSummary,
    });
    return Escalation.fromJson(res['data']);
  }

  static Future<List<Escalation>> getEscalations({String? status}) async {
    final query = status != null ? '?status=$status' : '';
    final res = await ApiService.get('/manager/escalations$query');
    final list = res['data'] as List? ?? [];
    return list.map((e) => Escalation.fromJson(e)).toList();
  }

  static Future<Escalation> resolveEscalation(
      String id, String resolutionNote) async {
    final res = await ApiService.put(
      '/manager/escalations/$id/resolve',
      {'resolution_note': resolutionNote},
    );
    return Escalation.fromJson(res['data']);
  }

  /// Returns the manager's notification feed and unread count.
  static Future<({List<NotificationItem> items, int unreadCount})>
      getNotifications({bool unreadOnly = false}) async {
    final query = unreadOnly ? '?unread_only=true' : '';
    final res = await ApiService.get('/manager/notifications$query');
    final list = (res['data'] as List? ?? [])
        .map((e) => NotificationItem.fromJson(e))
        .toList();
    return (items: list, unreadCount: (res['unread_count'] as int?) ?? 0);
  }

  static Future<void> markNotificationRead(String id) async {
    await ApiService.patch('/manager/notifications/$id/read', {});
  }

  static Future<void> markAllNotificationsRead() async {
    await ApiService.patch('/manager/notifications/all/read', {});
  }

  static Future<RouteSuggestion> suggestRouteOrder({
    required List<int> ordersIdorders,
    List<int>? stopOrder,
  }) async {
    final res = await ApiService.post('/manager/delivery-routes/suggest-order', {
      'orders_idorders': ordersIdorders,
      if (stopOrder != null) 'stop_order': stopOrder,
    });
    return RouteSuggestion.fromJson(res['data'] as Map<String, dynamic>);
  }

  static Future<DeliveryRoute> createDeliveryRoute({
    required List<int> ordersIdorders,
    required String riderId,
    List<int>? stopOrder,
  }) async {
    final res = await ApiService.post('/manager/delivery-routes', {
      'orders_idorders': ordersIdorders,
      'rider_id': riderId,
      if (stopOrder != null) 'stop_order': stopOrder,
    });
    final data = res['data'] as Map<String, dynamic>;
    return DeliveryRoute.fromJson(data['route'] as Map<String, dynamic>);
  }

  static Future<List<DeliveryRoute>> getDeliveryRoutes({String? status}) async {
    final query = status != null ? '?status=$status' : '';
    final res = await ApiService.get('/manager/delivery-routes$query');
    final list = res['data'] as List? ?? [];
    return list.map((e) => DeliveryRoute.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<DeliveryRoute> getDeliveryRoute(String routeId) async {
    final res = await ApiService.get('/manager/delivery-routes/$routeId');
    return DeliveryRoute.fromJson(res['data'] as Map<String, dynamic>);
  }
}
