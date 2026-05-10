class Order {
  final int ordersIdorders;
  final String storeCode;
  final String projectCode;
  final DateTime? orderDate;
  final String? deliveryDate;
  final int totalItems;
  final double totalAmount;
  final String status;
  final Assignment? currentAssignment;
  final bool sentToSuperAdmin;
  final DateTime? sentToSuperAdminAt;

  Order({
    required this.ordersIdorders,
    required this.storeCode,
    required this.projectCode,
    this.orderDate,
    this.deliveryDate,
    required this.totalItems,
    required this.totalAmount,
    required this.status,
    this.currentAssignment,
    this.sentToSuperAdmin = false,
    this.sentToSuperAdminAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        ordersIdorders: json['orders_idorders'] ?? 0,
        storeCode: json['store_code'] ?? '',
        projectCode: json['project_code'] ?? '',
        orderDate: json['order_date'] != null
            ? DateTime.tryParse(json['order_date'])
            : null,
        deliveryDate: json['delivery_date'],
        totalItems: json['total_items'] ?? 0,
        totalAmount: (json['total_amount'] ?? 0).toDouble(),
        status: json['status'] ?? 'pending',
        currentAssignment: json['current_assignment'] != null
            ? Assignment.fromJson(json['current_assignment'])
            : null,
        sentToSuperAdmin: json['sent_to_super_admin'] ?? false,
        sentToSuperAdminAt: json['sent_to_super_admin_at'] != null
            ? DateTime.tryParse(json['sent_to_super_admin_at'].toString())
            : null,
      );
}

class Assignment {
  final String id;
  final int ordersIdorders;
  final String storeCode;
  final String projectCode;
  final String status;
  final DateTime assignedAt;
  final DateTime? completedAt;
  final String? rejectedReason;
  final AssignedUser? assignedTo;
  final Order? order;

  Assignment({
    required this.id,
    required this.ordersIdorders,
    required this.storeCode,
    required this.projectCode,
    required this.status,
    required this.assignedAt,
    this.completedAt,
    this.rejectedReason,
    this.assignedTo,
    this.order,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) => Assignment(
        id: json['_id'] ?? json['assignment_id'] ?? '',
        ordersIdorders: json['orders_idorders'] ?? 0,
        storeCode: json['store_code'] ?? '',
        projectCode: json['project_code'] ?? '',
        status: json['status'] ?? 'assigned',
        assignedAt: DateTime.tryParse(json['assigned_at'] ?? '') ?? DateTime.now(),
        completedAt: json['completed_at'] != null
            ? DateTime.tryParse(json['completed_at'])
            : null,
        rejectedReason: json['rejected_reason'],
        assignedTo: json['assigned_to'] != null
            ? AssignedUser.fromJson(json['assigned_to'])
            : null,
        order: json['order'] != null ? Order.fromJson(json['order']) : null,
      );
}

class AssignedUser {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final int activeOrders;
  // Optional fields populated when the manager fetches the full picker list
  final String? role;
  final List<String> storeCodes;
  final String? projectCode;
  final String? fcmToken;
  final bool? isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AssignedUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.activeOrders = 0,
    this.role,
    this.storeCodes = const [],
    this.projectCode,
    this.fcmToken,
    this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory AssignedUser.fromJson(Map<String, dynamic> json) => AssignedUser(
        id: json['_id'] ?? '',
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'],
        activeOrders: json['active_orders'] ?? 0,
        role: json['role'],
        storeCodes: (json['store_codes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        projectCode: json['project_code'],
        fcmToken: json['fcm_token'],
        isActive: json['is_active'],
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
        updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
      );
}
