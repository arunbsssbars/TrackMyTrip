class PackingItem {
  final String id;
  final String tripId;
  final String title;
  final String category; // 'Documents', 'Clothing', 'Electronics', 'Medical', 'Gear', 'Vehicle'
  final bool isPacked;
  final String? assignedToMemberId;
  final String? assignedToMemberName;
  final int quantity;

  const PackingItem({
    required this.id,
    required this.tripId,
    required this.title,
    required this.category,
    this.isPacked = false,
    this.assignedToMemberId,
    this.assignedToMemberName,
    this.quantity = 1,
  });

  PackingItem copyWith({
    String? id,
    String? tripId,
    String? title,
    String? category,
    bool? isPacked,
    String? assignedToMemberId,
    String? assignedToMemberName,
    int? quantity,
  }) {
    return PackingItem(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      title: title ?? this.title,
      category: category ?? this.category,
      isPacked: isPacked ?? this.isPacked,
      assignedToMemberId: assignedToMemberId ?? this.assignedToMemberId,
      assignedToMemberName: assignedToMemberName ?? this.assignedToMemberName,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tripId': tripId,
    'title': title,
    'category': category,
    'isPacked': isPacked ? 1 : 0,
    'assignedToMemberId': assignedToMemberId,
    'assignedToMemberName': assignedToMemberName,
    'quantity': quantity,
  };

  factory PackingItem.fromJson(Map<String, dynamic> json) => PackingItem(
    id: json['id'] as String,
    tripId: json['tripId'] as String,
    title: json['title'] as String,
    category: json['category'] as String? ?? 'Gear',
    isPacked: json['isPacked'] == 1 || json['isPacked'] == true,
    assignedToMemberId: json['assignedToMemberId'] as String?,
    assignedToMemberName: json['assignedToMemberName'] as String?,
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
  );
}
