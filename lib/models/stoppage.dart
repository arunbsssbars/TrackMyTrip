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
  final String? createdByName;
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
    this.createdByName,
    this.orderIndex = 0,
  });

  bool get isOngoing => departedAt == null;

  Duration? get duration {
    if (departedAt == null) return null;
    return departedAt!.difference(arrivedAt);
  }

  String get formattedDuration {
    if (departedAt == null) {
      final diff = DateTime.now().difference(arrivedAt);
      if (diff.isNegative) return 'Just arrived';
      if (diff.inHours >= 1) {
        return 'Ongoing: ${diff.inHours}h ${diff.inMinutes % 60}m';
      }
      return 'Ongoing: ${diff.inMinutes}m';
    }
    final d = departedAt!.difference(arrivedAt);
    if (d.inHours >= 1) {
      return '${d.inHours}h ${d.inMinutes % 60}m';
    }
    return '${d.inMinutes}m';
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
    String? createdByName,
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
      createdByName: createdByName ?? this.createdByName,
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
      'createdByName': createdByName,
      'orderIndex': orderIndex,
    };
  }

  factory Stoppage.fromJson(Map<String, dynamic> json) {
    return Stoppage(
      id: json['id'] as String? ?? '',
      tripId: json['tripId'] as String? ?? '',
      name: json['name'] as String? ?? 'Waypoint',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      address: json['address'] as String?,
      category: json['category'] as String? ?? 'Other',
      arrivedAt: json['arrivedAt'] != null
          ? (DateTime.tryParse(json['arrivedAt'] as String) ?? DateTime.now())
          : DateTime.now(),
      departedAt: json['departedAt'] != null
          ? DateTime.tryParse(json['departedAt'] as String)
          : null,
      notes: json['notes'] as String?,
      createdBy: json['createdBy'] as String? ?? '',
      createdByName: json['createdByName'] as String?,
      orderIndex: json['orderIndex'] as int? ?? 0,
    );
  }
}
