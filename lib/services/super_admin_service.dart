import '../models/item_model.dart';
import '../models/notification_model.dart';
import '../models/order_model.dart';
import 'api_service.dart';

class SuperAdminKpis {
  final int totalSent;
  final int sentThisMonth;
  final double totalAmount;
  final int storesCovered;
  final DeliveryKpis delivery;

  SuperAdminKpis({
    required this.totalSent,
    required this.sentThisMonth,
    required this.totalAmount,
    required this.storesCovered,
    required this.delivery,
  });

  factory SuperAdminKpis.fromJson(Map<String, dynamic> json) => SuperAdminKpis(
        totalSent: json['total_sent'] ?? 0,
        sentThisMonth: json['sent_this_month'] ?? 0,
        totalAmount: (json['total_amount'] ?? 0).toDouble(),
        storesCovered: json['stores_covered'] ?? 0,
        delivery: DeliveryKpis.fromJson(
          (json['delivery'] as Map<String, dynamic>?) ?? {},
        ),
      );
}

class DeliveryKpis {
  final int readyForDelivery;
  final int outForDelivery;
  final int deliveredToday;
  final int failed;
  final int activeRiders;

  DeliveryKpis({
    required this.readyForDelivery,
    required this.outForDelivery,
    required this.deliveredToday,
    required this.failed,
    required this.activeRiders,
  });

  factory DeliveryKpis.fromJson(Map<String, dynamic> json) => DeliveryKpis(
        readyForDelivery: json['ready_for_delivery'] ?? 0,
        outForDelivery: json['out_for_delivery'] ?? 0,
        deliveredToday: json['delivered_today'] ?? 0,
        failed: json['failed'] ?? 0,
        activeRiders: json['active_riders'] ?? 0,
      );
}

class SuperAdminService {
  static Future<SuperAdminKpis> getDashboard() async {
    final res = await ApiService.get('/super-admin/dashboard');
    return SuperAdminKpis.fromJson(res['data'] as Map<String, dynamic>);
  }

  static Future<List<Order>> getOrders({String? storeCode}) async {
    final query = storeCode != null && storeCode.isNotEmpty
        ? '?store_code=$storeCode'
        : '';
    final res = await ApiService.get('/super-admin/orders$query');
    final list = res['data'] as List? ?? [];
    return list.map((e) => Order.fromJson(e)).toList();
  }

  static Future<Order?> getOrder(int ordersIdorders) async {
    final orders = await getOrders();
    for (final o in orders) {
      if (o.ordersIdorders == ordersIdorders) return o;
    }
    return null;
  }

  static Future<List<OrderItem>> getOrderItems(int ordersIdorders) async {
    final res = await ApiService.get(
      '/super-admin/orders/$ordersIdorders/items',
    );
    final list = res['data'] as List? ?? [];
    return list.map((e) => OrderItem.fromJson(e)).toList();
  }

  static Future<({List<NotificationItem> items, int unreadCount})>
      getNotifications() async {
    final res = await ApiService.get('/super-admin/notifications');
    final list = res['data'] as List? ?? [];
    final items = list.map((e) => NotificationItem.fromJson(e)).toList();
    final int unread = (res['unread_count'] as num?)?.toInt() ?? 0;
    return (items: items, unreadCount: unread);
  }

  static Future<void> markNotificationRead(String id) async {
    await ApiService.patch('/super-admin/notifications/$id/read', {});
  }

  static Future<void> markAllNotificationsRead() async {
    await ApiService.patch('/super-admin/notifications/all/read', {});
  }
}
