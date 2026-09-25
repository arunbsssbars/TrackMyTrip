import 'trip_member.dart';

class Trip {
  final String id;
  final String title;
  final String? description;
  final String? coverImageUrl;
  final DateTime startDate;
  final DateTime endDate;
  final String defaultCurrency;
  final double? budget;
  final String? shareCode;
  final String tripType; // 'group', 'family', 'solo'
  final List<TripMember> members;
  final String createdByMemberId;
  final DateTime createdAt;
  final bool isCompleted;
  final String status; // 'active', 'completed', 'deleted'
  final double? rating;
  final String? experienceReview;
  final DateTime? completedAt;

  const Trip({
    required this.id,
    required this.title,
    this.description,
    this.coverImageUrl,
    required this.startDate,
    required this.endDate,
    required this.defaultCurrency,
    this.budget,
    this.shareCode,
    this.tripType = 'group',
    required this.members,
    required this.createdByMemberId,
    required this.createdAt,
    this.isCompleted = false,
    this.status = 'active',
    this.rating,
    this.experienceReview,
    this.completedAt,
  });

  bool get isSolo => tripType == 'solo' || members.length <= 1;
  bool get isFamily => tripType == 'family';
  bool get isGroup => tripType == 'group' && !isSolo;
  bool get hasSettlements => isGroup;
  bool get isRunning => !isCompleted && !isDeleted;
  bool get isEnded => isCompleted || status == 'completed';
  bool get isDeleted => status == 'deleted';

  TripMember? get currentUserMember {
    for (final m in members) {
      if (m.isCurrentUser) return m;
    }
    return members.isNotEmpty ? members.first : null;
  }

  TripMember? getMember(String memberId) {
    for (final m in members) {
      if (m.id == memberId) return m;
    }
    return null;
  }

  String getMemberName(String memberId) {
    return getMember(memberId)?.name ?? 'Unknown Member';
  }

  bool isCreator(String? userId) {
    if (userId == null || userId.isEmpty) return false;
    if (createdByMemberId == userId) return true;
    final member = getMember(userId);
    if (member != null && member.id == createdByMemberId) return true;
    return false;
  }

  bool hasMember(String? userId, [String? userEmail]) {
    if (userId == null && userEmail == null) return false;
    return members.any((m) =>
      (userId != null && m.id == userId) ||
      (userEmail != null && userEmail.isNotEmpty && m.email != null && m.email!.trim().toLowerCase() == userEmail.trim().toLowerCase())
    );
  }


  Trip copyWith({
    String? id,
    String? title,
    String? description,
    String? coverImageUrl,
    DateTime? startDate,
    DateTime? endDate,
    String? defaultCurrency,
    double? budget,
    String? shareCode,
    String? tripType,
    List<TripMember>? members,
    String? createdByMemberId,
    DateTime? createdAt,
    bool? isCompleted,
    String? status,
    double? rating,
    String? experienceReview,
    DateTime? completedAt,
  }) {
    return Trip(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      budget: budget ?? this.budget,
      shareCode: shareCode ?? this.shareCode,
      tripType: tripType ?? this.tripType,
      members: members ?? this.members,
      createdByMemberId: createdByMemberId ?? this.createdByMemberId,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      experienceReview: experienceReview ?? this.experienceReview,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'coverImageUrl': coverImageUrl,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'defaultCurrency': defaultCurrency,
      'budget': budget,
      'shareCode': shareCode,
      'tripType': tripType,
      'members': members.map((m) => m.toJson()).toList(),
      'createdByMemberId': createdByMemberId,
      'creatorId': createdByMemberId,
      'memberIds': members.map((m) => m.id).toList(),
      'memberEmails': members.map((m) => m.email).where((e) => e != null && e.isNotEmpty).cast<String>().toList(),
      'createdAt': createdAt.toIso8601String(),
      'isCompleted': isCompleted,
      'status': status,
      'rating': rating,
      'experienceReview': experienceReview,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    final isCompletedVal = json['isCompleted'] as bool? ?? false;
    return Trip(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      coverImageUrl: json['coverImageUrl'] as String?,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      defaultCurrency: json['defaultCurrency'] as String? ?? 'USD',
      budget: (json['budget'] as num?)?.toDouble(),
      shareCode: json['shareCode'] as String?,
      tripType: json['tripType'] as String? ?? 'group',
      members: (json['members'] as List<dynamic>?)
              ?.map((e) => TripMember.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdByMemberId: (json['createdByMemberId'] as String?) ??
          (json['creatorId'] as String?) ??
          '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      isCompleted: isCompletedVal,
      status: (json['status'] as String?) ?? (isCompletedVal ? 'completed' : 'active'),
      rating: (json['rating'] as num?)?.toDouble(),
      experienceReview: json['experienceReview'] as String?,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }
}
