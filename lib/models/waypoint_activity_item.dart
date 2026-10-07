class WaypointActivityItem {
  final String id;
  final String stoppageId;
  final String title;
  final String? assignedMemberName;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? note;

  const WaypointActivityItem({
    required this.id,
    required this.stoppageId,
    required this.title,
    this.assignedMemberName,
    this.isCompleted = false,
    required this.createdAt,
    this.completedAt,
    this.note,
  });

  WaypointActivityItem copyWith({
    String? id,
    String? stoppageId,
    String? title,
    String? assignedMemberName,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    String? note,
  }) {
    return WaypointActivityItem(
      id: id ?? this.id,
      stoppageId: stoppageId ?? this.stoppageId,
      title: title ?? this.title,
      assignedMemberName: assignedMemberName ?? this.assignedMemberName,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'stoppageId': stoppageId,
        'title': title,
        'assignedMemberName': assignedMemberName,
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'note': note,
      };

  factory WaypointActivityItem.fromJson(Map<String, dynamic> json) {
    return WaypointActivityItem(
      id: json['id'] as String? ?? '',
      stoppageId: json['stoppageId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      assignedMemberName: json['assignedMemberName'] as String?,
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      note: json['note'] as String?,
    );
  }
}
