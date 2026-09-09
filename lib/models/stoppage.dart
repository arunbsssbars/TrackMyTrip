class Stoppage {
  final String id;
  final String tripId;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final String category;
  final DateTime arrivedAt;
  final DateTime? departedAt;
  final String? notes;
  final String createdBy;
  final int orderIndex;

  const Stoppage({
    required this.id,
    required this.tripId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    required this.category,
    required this.arrivedAt,
    this.departedAt,
    this.notes,
    required this.createdBy,
    this.orderIndex = 0,
  });

  bool get isOngoing => departedAt == null;

  Duration? get duration {
    if (departedAt == null) return null;
    return departedAt!.difference(arrivedAt);
  }

  Stoppage copyWith({
    String? id,
    String? tripId,
    String? name,
    double? latitude,
    double? longitude,
    String? address,
    String? category,
    DateTime? arrivedAt,
    DateTime? departedAt,
    bool clearDepartedAt = false,
    String? notes,
    String? createdBy,
    int? orderIndex,
  }) {
    return Stoppage(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      category: category ?? this.category,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      departedAt: clearDepartedAt ? null : (departedAt ?? this.departedAt),
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'category': category,
      'arrivedAt': arrivedAt.toIso8601String(),
      'departedAt': departedAt?.toIso8601String(),
      'notes': notes,
      'createdBy': createdBy,
      'orderIndex': orderIndex,
    };
  }

  factory Stoppage.fromJson(Map<String, dynamic> json) {
    return Stoppage(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
      category: json['category'] as String,
      arrivedAt: DateTime.parse(json['arrivedAt'] as String),
      departedAt: json['departedAt'] != null ? DateTime.parse(json['departedAt'] as String) : null,
      notes: json['notes'] as String?,
      createdBy: json['createdBy'] as String,
      orderIndex: json['orderIndex'] as int? ?? 0,
    );
  }
}
