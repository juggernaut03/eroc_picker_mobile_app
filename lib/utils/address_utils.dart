/// Parses the flat, comma-joined `delivery_details` string that the backend
/// sends (e.g. "Gaurav Pawar, 101 room 203, taloja phase 1, 410208, 8108053372")
/// into structured, presentable parts.
///
/// The upstream format is not perfectly rigid, so we detect the pincode and
/// phone by shape (6-digit / 10-digit numeric tokens) rather than by position,
/// and treat the first token as the customer name and everything in between as
/// the street address.
class DeliveryAddress {
  final String? name;
  final String? addressLine;
  final String? pincode;
  final String? phone;
  final String raw;

  const DeliveryAddress({
    this.name,
    this.addressLine,
    this.pincode,
    this.phone,
    required this.raw,
  });

  bool get isEmpty =>
      (name == null || name!.isEmpty) &&
      (addressLine == null || addressLine!.isEmpty) &&
      pincode == null &&
      phone == null;

  static final _pinRe = RegExp(r'^\d{6}$');
  static final _phoneRe = RegExp(r'^\+?\d{10,13}$');

  factory DeliveryAddress.parse(String? details) {
    final raw = (details ?? '').trim();
    if (raw.isEmpty) return DeliveryAddress(raw: raw);

    final parts = raw
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    String? pincode;
    String? phone;
    final rest = <String>[];

    for (final p in parts) {
      final digits = p.replaceAll(RegExp(r'[\s-]'), '');
      if (pincode == null && _pinRe.hasMatch(digits)) {
        pincode = digits;
      } else if (phone == null && _phoneRe.hasMatch(digits)) {
        phone = digits;
      } else {
        rest.add(p);
      }
    }

    String? name;
    String? addressLine;
    if (rest.isNotEmpty) {
      name = rest.first;
      if (rest.length > 1) {
        addressLine = rest.sublist(1).join(', ');
      }
    }

    return DeliveryAddress(
      name: name,
      addressLine: addressLine,
      pincode: pincode,
      phone: phone,
      raw: raw,
    );
  }

  /// Address portion only (street + pincode), for map/nav or one-line summaries.
  String get fullAddress {
    final bits = <String>[
      if (addressLine != null && addressLine!.isNotEmpty) addressLine!,
      ?pincode,
    ].where((b) => b.isNotEmpty).toList();
    return bits.join(', ');
  }
}
