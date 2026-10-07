class VehicleMaintenanceMilestone {
  final String id;
  final String tripId;
  final String vehicleName;
  final double odometerKm;
  final String milestoneType; // 'toll', 'fuel_topup', 'tyre_check', 'oil_service', 'breakdown'
  final double cost;
  final String currency;
  final String notes;
  final DateTime recordedAt;

  const VehicleMaintenanceMilestone({
    required this.id,
    required this.tripId,
    required this.vehicleName,
    required this.odometerKm,
    required this.milestoneType,
    this.cost = 0.0,
    this.currency = 'INR',
    this.notes = '',
    required this.recordedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'tripId': tripId,
        'vehicleName': vehicleName,
        'odometerKm': odometerKm,
        'milestoneType': milestoneType,
        'cost': cost,
        'currency': currency,
        'notes': notes,
        'recordedAt': recordedAt.toIso8601String(),
      };

  factory VehicleMaintenanceMilestone.fromJson(Map<String, dynamic> json) {
    return VehicleMaintenanceMilestone(
      id: json['id'] as String? ?? '',
      tripId: json['tripId'] as String? ?? '',
      vehicleName: json['vehicleName'] as String? ?? 'Vehicle',
      odometerKm: (json['odometerKm'] as num?)?.toDouble() ?? 0.0,
      milestoneType: json['milestoneType'] as String? ?? 'toll',
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'INR',
      notes: json['notes'] as String? ?? '',
      recordedAt: json['recordedAt'] != null
          ? DateTime.tryParse(json['recordedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  VehicleMaintenanceMilestone copyWith({
    String? id,
    String? tripId,
    String? vehicleName,
    double? odometerKm,
    String? milestoneType,
    double? cost,
    String? currency,
    String? notes,
    DateTime? recordedAt,
  }) {
    return VehicleMaintenanceMilestone(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      vehicleName: vehicleName ?? this.vehicleName,
      odometerKm: odometerKm ?? this.odometerKm,
      milestoneType: milestoneType ?? this.milestoneType,
      cost: cost ?? this.cost,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }
}
