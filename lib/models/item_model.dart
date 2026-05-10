class OrderItem {
  final String id;
  final int ordersIdorders;
  final String? pCode;
  final String? barcode;
  final String? itemName;
  final String? pcodeImg;
  final String? packSize;
  final double? productOfferPrice;
  final double? productMrp;
  final int orderedQuantity;
  final ItemPickerStatus? pickerStatus;

  OrderItem({
    required this.id,
    required this.ordersIdorders,
    this.pCode,
    this.barcode,
    this.itemName,
    this.pcodeImg,
    this.packSize,
    this.productOfferPrice,
    this.productMrp,
    required this.orderedQuantity,
    this.pickerStatus,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: json['_id'] ?? '',
        ordersIdorders: json['orders_idorders'] ?? 0,
        pCode: json['p_code'],
        barcode: json['barcode'],
        itemName: json['item_name'],
        pcodeImg: json['pcode_img'],
        packSize: json['pack_size'],
        productOfferPrice: (json['product_offer_price'] as num?)?.toDouble(),
        productMrp: (json['product_mrp'] as num?)?.toDouble(),
        orderedQuantity: json['ordered_quantity'] ?? 0,
        pickerStatus: json['picker_status'] != null
            ? ItemPickerStatus.fromJson(json['picker_status'])
            : null,
      );
}

class ItemPickerStatus {
  final String id;
  final String assignmentId;
  final String orderItemId;
  final String pickedStatus;
  final int pickedQuantity;
  final String? remark;
  final String? photoUrl;
  final DateTime? pickedAt;

  ItemPickerStatus({
    required this.id,
    required this.assignmentId,
    required this.orderItemId,
    required this.pickedStatus,
    required this.pickedQuantity,
    this.remark,
    this.photoUrl,
    this.pickedAt,
  });

  factory ItemPickerStatus.fromJson(Map<String, dynamic> json) =>
      ItemPickerStatus(
        id: json['_id'] ?? '',
        assignmentId: json['assignment_id'] ?? '',
        orderItemId: json['order_item_id'] ?? '',
        pickedStatus: json['picked_status'] ?? 'pending',
        pickedQuantity: json['picked_quantity'] ?? 0,
        remark: json['remark'],
        photoUrl: json['photo_url'],
        pickedAt: json['picked_at'] != null
            ? DateTime.tryParse(json['picked_at'])
            : null,
      );

  bool get isPending => pickedStatus == 'pending';
  bool get isPicked => pickedStatus == 'picked';
}

class Remark {
  final String id;
  final String assignmentId;
  final int ordersIdorders;
  final String? itemName;
  final String pickedStatus;
  final String? remark;
  final RemarkPicker? pickedBy;
  final DateTime? pickedAt;

  Remark({
    required this.id,
    required this.assignmentId,
    required this.ordersIdorders,
    this.itemName,
    required this.pickedStatus,
    this.remark,
    this.pickedBy,
    this.pickedAt,
  });

  factory Remark.fromJson(Map<String, dynamic> json) => Remark(
        id: json['_id'] ?? '',
        assignmentId: json['assignment_id'] ?? '',
        ordersIdorders: json['orders_idorders'] ?? 0,
        itemName: json['item_name'],
        pickedStatus: json['picked_status'] ?? '',
        remark: json['remark'],
        pickedBy: json['picked_by'] != null
            ? RemarkPicker.fromJson(json['picked_by'])
            : null,
        pickedAt: json['picked_at'] != null
            ? DateTime.tryParse(json['picked_at'])
            : null,
      );
}

class RemarkPicker {
  final String id;
  final String name;
  final String email;

  RemarkPicker({required this.id, required this.name, required this.email});

  factory RemarkPicker.fromJson(Map<String, dynamic> json) => RemarkPicker(
        id: json['_id'] ?? '',
        name: json['name'] ?? '',
        email: json['email'] ?? '',
      );
}

class Escalation {
  final String id;
  final String assignmentId;
  final int ordersIdorders;
  final String? itemStatusId;
  final String? itemName;
  final String? storeCode;
  final String remarkSummary;
  final String status;
  final String? resolutionNote;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final String? raisedByName;

  Escalation({
    required this.id,
    required this.assignmentId,
    required this.ordersIdorders,
    this.itemStatusId,
    this.itemName,
    this.storeCode,
    required this.remarkSummary,
    required this.status,
    this.resolutionNote,
    this.resolvedAt,
    required this.createdAt,
    this.raisedByName,
  });

  factory Escalation.fromJson(Map<String, dynamic> json) => Escalation(
        id: json['_id'] ?? '',
        assignmentId: json['assignment_id'] is String
            ? json['assignment_id']
            : (json['assignment_id']?['_id'] ?? ''),
        ordersIdorders: json['orders_idorders'] ?? 0,
        itemStatusId: json['item_status_id'] is String
            ? json['item_status_id']
            : (json['item_status_id']?['_id']),
        itemName: json['item_name'],
        storeCode: json['store_code'],
        remarkSummary: json['remark_summary'] ?? '',
        status: json['status'] ?? 'open',
        resolutionNote: json['resolution_note'],
        resolvedAt: json['resolved_at'] != null
            ? DateTime.tryParse(json['resolved_at'])
            : null,
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        raisedByName: json['raised_by'] is Map
            ? json['raised_by']['name']
            : null,
      );

  bool get isOpen => status == 'open';
}
