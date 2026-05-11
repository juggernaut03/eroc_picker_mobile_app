import '../models/item_model.dart';
import '../models/notification_model.dart';
import '../models/order_model.dart';
import 'api_service.dart';

class SuperAdminKpis {
  final int totalSent;
  final int sentThisMonth;
  final double totalAmount;
  final int storesCovered;

  SuperAdminKpis({
    required this.totalSent,
    required this.sentThisMonth,
    required this.totalAmount,
    required this.storesCovered,
  });

  factory SuperAdminKpis.fromJson(Map<String, dynamic> json) => SuperAdminKpis(
        totalSent: json['total_sent'] ?? 0,
        sentThisMonth: json['sent_this_month'] ?? 0,
        totalAmount: (json['total_amount'] ?? 0).toDouble(),
        storesCovered: json['stores_covered'] ?? 0,
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
