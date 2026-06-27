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
  final String? deliveryStatus;
  final String? deliverySlot;
  final String? deliveryDetails;
  final String? latitude;
  final String? longitude;
  final DeliveryAssignment? currentDeliveryAssignment;

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
    this.deliveryStatus,
    this.deliverySlot,
    this.deliveryDetails,
    this.latitude,
    this.longitude,
    this.currentDeliveryAssignment,
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
        deliveryStatus: json['delivery_status'],
        deliverySlot: json['delivery_slot'],
        deliveryDetails: json['delivery_details'],
        latitude: json['latitude']?.toString(),
        longitude: json['longitude']?.toString(),
        currentDeliveryAssignment: json['current_delivery_assignment'] != null
            ? DeliveryAssignment.fromJson(json['current_delivery_assignment'])
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
        activeOrders: json['active_orders'] ?? json['active_deliveries'] ?? 0,
        role: json['role'],
        storeCodes: (json['store_codes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        projectCode: json['project_code'],
        fcmToken: json['fcm_token'],
        isActive: json['is_active'],
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
        updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
      );
}

class DeliveryAssignment {
  final String id;
  final int ordersIdorders;
  final String storeCode;
  final String projectCode;
  final String status;
  final DateTime assignedAt;
  final DateTime? startedAt;
  final DateTime? deliveredAt;
  final String? failedReason;
  final AssignedUser? rider;
  final Order? order;
  final List<String> podPhotoUrls;
  final String? podNotes;
  final String? routeId;
  final int? stopSequence;

  DeliveryAssignment({
    required this.id,
    required this.ordersIdorders,
    required this.storeCode,
    required this.projectCode,
    required this.status,
    required this.assignedAt,
    this.startedAt,
    this.deliveredAt,
    this.failedReason,
    this.rider,
    this.order,
    this.podPhotoUrls = const [],
    this.podNotes,
    this.routeId,
    this.stopSequence,
  });

  factory DeliveryAssignment.fromJson(Map<String, dynamic> json) {
    final pod = json['proof_of_delivery'] as Map<String, dynamic>?;
    final riderJson = json['rider_id'];
    return DeliveryAssignment(
      id: json['_id'] ?? json['assignment_id'] ?? '',
      ordersIdorders: json['orders_idorders'] ?? 0,
      storeCode: json['store_code'] ?? '',
      projectCode: json['project_code'] ?? '',
      status: json['status'] ?? 'assigned',
      assignedAt: DateTime.tryParse(json['assigned_at'] ?? '') ?? DateTime.now(),
      startedAt: json['started_at'] != null ? DateTime.tryParse(json['started_at']) : null,
      deliveredAt: json['delivered_at'] != null ? DateTime.tryParse(json['delivered_at']) : null,
      failedReason: json['failed_reason'],
      rider: riderJson is Map
          ? AssignedUser.fromJson(Map<String, dynamic>.from(riderJson as Map))
          : null,
      order: json['order'] != null ? Order.fromJson(json['order']) : null,
      podPhotoUrls: List<String>.from(pod?['photo_urls'] ?? []),
      podNotes: pod?['notes'],
      routeId: json['route_id']?.toString(),
      stopSequence: json['stop_sequence'],
    );
  }
}
