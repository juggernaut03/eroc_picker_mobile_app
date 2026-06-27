class UiConfig {
  final List<NavItem> navItems;
  final List<String> orderActions;
  final List<String> itemActions;
  final bool canReassign;
  final bool canEscalate;
  final bool canViewAllStores;
  // Full effective capability map (capKey -> bool) from the backend.
  final Map<String, bool> capabilities;

  UiConfig({
    required this.navItems,
    required this.orderActions,
    required this.itemActions,
    required this.canReassign,
    required this.canEscalate,
    required this.canViewAllStores,
    this.capabilities = const {},
  });

  factory UiConfig.fromJson(Map<String, dynamic> json) => UiConfig(
        navItems: (json['nav_items'] as List? ?? [])
            .map((e) => NavItem.fromJson(e))
            .toList(),
        orderActions:
            List<String>.from(json['order_actions'] ?? []),
        itemActions: List<String>.from(json['item_actions'] ?? []),
        canReassign: json['can_reassign'] ?? false,
        canEscalate: json['can_escalate'] ?? false,
        canViewAllStores: json['can_view_all_stores'] ?? false,
        capabilities: (json['capabilities'] as Map?)
                ?.map((k, v) => MapEntry(k.toString(), v == true)) ??
            const {},
      );

  // Capability check. Fallback rule: if the capabilities map is empty (an old
  // cached session from before this feature), be permissive so users aren't
  // locked out before the next /auth/me refresh. The backend 403 remains the
  // hard gate regardless.
  bool can(String key) {
    if (capabilities.isEmpty) return true;
    return capabilities[key] == true;
  }
}

class NavItem {
  final String key;
  final String label;
  final String icon;

  NavItem({required this.key, required this.label, required this.icon});

  factory NavItem.fromJson(Map<String, dynamic> json) => NavItem(
        key: json['key'],
        label: json['label'],
        icon: json['icon'],
      );
}

class PickerUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final List<String> storeCodes;
  final String projectCode;
  final bool isActive;

  PickerUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.storeCodes,
    required this.projectCode,
    this.isActive = true,
  });

  factory PickerUser.fromJson(Map<String, dynamic> json) => PickerUser(
        id: json['id'] ?? json['_id'] ?? '',
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        role: json['role'] ?? '',
        storeCodes: List<String>.from(json['store_codes'] ?? []),
        projectCode: json['project_code'] ?? '',
        isActive: json['is_active'] ?? true,
      );

  PickerUser copyWith({bool? isActive}) => PickerUser(
        id: id,
        name: name,
        email: email,
        role: role,
        storeCodes: storeCodes,
        projectCode: projectCode,
        isActive: isActive ?? this.isActive,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'store_codes': storeCodes,
        'project_code': projectCode,
        'is_active': isActive,
      };

  bool get isManager => role == 'manager';
  bool get isPicker => role == 'picker';
  bool get isAdmin => role == 'admin';
  bool get isRider => role == 'rider';
}
