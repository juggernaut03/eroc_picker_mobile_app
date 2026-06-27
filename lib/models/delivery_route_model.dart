import 'order_model.dart';

class RouteStop {
  final int sequence;
  final int ordersIdorders;
  final String? latitude;
  final String? longitude;
  final String status;
  final Order? order;
  final DeliveryAssignment? assignment;

  RouteStop({
    required this.sequence,
    required this.ordersIdorders,
    this.latitude,
    this.longitude,
    this.status = 'pending',
    this.order,
    this.assignment,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      sequence: json['sequence'] ?? 0,
      ordersIdorders: json['orders_idorders'] ?? 0,
      latitude: json['latitude'],
      longitude: json['longitude'],
      status: json['status'] ?? 'pending',
      order: json['order'] != null ? Order.fromJson(json['order']) : null,
      assignment: json['assignment'] != null
          ? DeliveryAssignment.fromJson(json['assignment'])
          : null,
    );
  }
}

class DeliveryRoute {
  final String id;
  final String storeCode;
  final String projectCode;
  final String status;
  final String? deliveryDate;
  final String? deliverySlot;
  final int? estimatedDurationMin;
  final double? estimatedDistanceKm;
  final List<RouteStop> stops;
  final String? mapsUrl;
  final int pendingStops;
  final RouteStop? currentStop;
  final AssignedUser? rider;

  DeliveryRoute({
    required this.id,
    required this.storeCode,
    required this.projectCode,
    required this.status,
    this.deliveryDate,
    this.deliverySlot,
    this.estimatedDurationMin,
    this.estimatedDistanceKm,
    this.stops = const [],
    this.mapsUrl,
    this.pendingStops = 0,
    this.currentStop,
    this.rider,
  });

  factory DeliveryRoute.fromJson(Map<String, dynamic> json) {
    final riderJson = json['rider_id'];
    return DeliveryRoute(
      id: json['_id'] ?? '',
      storeCode: json['store_code'] ?? '',
      projectCode: json['project_code'] ?? '',
      status: json['status'] ?? 'planned',
      deliveryDate: json['delivery_date'],
      deliverySlot: json['delivery_slot'],
      estimatedDurationMin: json['estimated_duration_min'],
      estimatedDistanceKm: (json['estimated_distance_km'] as num?)?.toDouble(),
      stops: (json['stops'] as List? ?? [])
          .map((e) => RouteStop.fromJson(e as Map<String, dynamic>))
          .toList(),
      mapsUrl: json['maps_url'],
      pendingStops: json['pending_stops'] ?? 0,
      currentStop: json['current_stop'] != null
          ? RouteStop.fromJson(json['current_stop'] as Map<String, dynamic>)
          : null,
      rider: riderJson is Map
          ? AssignedUser.fromJson(Map<String, dynamic>.from(riderJson))
          : null,
    );
  }
}

class RouteSuggestion {
  final List<int> stopOrder;
  final int estimatedDurationMin;
  final double estimatedDistanceKm;
  final String? mapsUrl;

  RouteSuggestion({
    required this.stopOrder,
    required this.estimatedDurationMin,
    required this.estimatedDistanceKm,
    this.mapsUrl,
  });

  factory RouteSuggestion.fromJson(Map<String, dynamic> json) {
    return RouteSuggestion(
      stopOrder: List<int>.from(json['stop_order'] ?? []),
      estimatedDurationMin: json['estimated_duration_min'] ?? 0,
      estimatedDistanceKm: (json['estimated_distance_km'] as num?)?.toDouble() ?? 0,
      mapsUrl: json['maps_url'],
    );
  }
}
