class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic> metadata;
  final bool read;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.metadata,
    required this.read,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
        id: json['_id'] ?? '',
        title: json['title'] ?? '',
        body: json['body'] ?? '',
        type: json['type'] ?? 'info',
        metadata: Map<String, dynamic>.from(json['metadata'] ?? const {}),
        read: json['read'] ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      );

  NotificationItem copyWith({bool? read}) => NotificationItem(
        id: id,
        title: title,
        body: body,
        type: type,
        metadata: metadata,
        read: read ?? this.read,
        createdAt: createdAt,
      );
}
