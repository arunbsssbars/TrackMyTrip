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
  final Map<String, double> memberRatings;
  final Map<String, String> memberReviews;

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
    this.memberRatings = const {},
    this.memberReviews = const {},
  });

  bool get isSolo => tripType == 'solo' || members.length <= 1;
  bool get isFamily => tripType == 'family';
  bool get isGroup => tripType == 'group' && !isSolo;
  bool get isEnded => isCompleted || status == 'completed' || status == 'concluded' || status == 'ended' || status == 'archived_by_creator';
  bool get isRunning => !isEnded && !isDeleted;
  bool get isArchivedByCreator => status == 'archived_by_creator';
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

  bool isCreator(String? userId, [String? userEmail]) {
    if ((userId == null || userId.isEmpty) && (userEmail == null || userEmail.isEmpty)) return false;
    if (userId != null && createdByMemberId == userId) return true;
    final member = userId != null ? getMember(userId) : null;
    if (member != null && (member.id == createdByMemberId || member.isCreator)) return true;
    if (userEmail != null && userEmail.isNotEmpty) {
      final clean = userEmail.trim().toLowerCase();
      final creatorMember = members.where((m) => m.id == createdByMemberId || m.isCreator).firstOrNull;
      if (creatorMember != null && creatorMember.email != null && creatorMember.email!.trim().toLowerCase() == clean) {
        return true;
      }
    }
    return false;
  }

  /// Determines if a member has the Creator role for this trip
  bool isMemberCreator(TripMember member) {
    if (member.isCreator) return true;
    if (createdByMemberId.isNotEmpty && member.id == createdByMemberId) return true;
    return isCreator(member.id, member.email);
  }

  bool hasMember(String? userId, [String? userEmail]) {
    if (userId == null && userEmail == null) return false;
    return members.any((m) =>
      (userId != null && m.id == userId) ||
      (userEmail != null && userEmail.isNotEmpty && m.email != null && m.email!.trim().toLowerCase() == userEmail.trim().toLowerCase())
    );
  }


  int get reviewCount => memberRatings.length;

  double? get averageRating {
    if (memberRatings.isNotEmpty) {
      final total = memberRatings.values.fold<double>(0.0, (sum, r) => sum + r);
      return double.parse((total / memberRatings.length).toStringAsFixed(1));
    }
    return rating;
  }

  /// Deduplicates trip members by both unique ID and case-insensitive email address.
  /// If a registered companion joins with a verified display name, it replaces placeholder invitations.
  static List<TripMember> deduplicateMembers(List<TripMember> memberList) {
    final seenIds = <String>{};
    final seenEmails = <String>{};
    final deduped = <TripMember>[];
    for (final m in memberList) {
      final cleanEmail = (m.email != null && m.email!.trim().isNotEmpty)
          ? m.email!.trim().toLowerCase()
          : null;
      if (seenIds.contains(m.id)) continue;
      if (cleanEmail != null && seenEmails.contains(cleanEmail)) {
        final existingIndex = deduped.indexWhere((existing) =>
            existing.email != null &&
            existing.email!.trim().toLowerCase() == cleanEmail);
        if (existingIndex != -1) {
          final existing = deduped[existingIndex];
          // Upgrade placeholder or custom/offline member with verified profile
          if (existing.id.startsWith('custom_') ||
              existing.id.startsWith('offline_') ||
              existing.id.startsWith('mbr_') ||
              existing.id.startsWith('member_') ||
              existing.name.toLowerCase().replaceAll('_', '') == cleanEmail.split('@').first) {
            deduped[existingIndex] = m;
          }
        }
        continue;
      }
      seenIds.add(m.id);
      if (cleanEmail != null) seenEmails.add(cleanEmail);
      deduped.add(m);
    }
    return deduped;
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
    Map<String, double>? memberRatings,
    Map<String, String>? memberReviews,
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
      memberRatings: memberRatings ?? this.memberRatings,
      memberReviews: memberReviews ?? this.memberReviews,
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
      'rating': rating ?? averageRating,
      'experienceReview': experienceReview,
      'completedAt': completedAt?.toIso8601String(),
      'memberRatings': memberRatings,
      'memberReviews': memberReviews,
    };
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    final isCompletedVal = json['isCompleted'] as bool? ?? false;
    final Map<String, double> parsedMemberRatings = {};
    if (json['memberRatings'] is Map) {
      (json['memberRatings'] as Map).forEach((k, v) {
        if (v is num) parsedMemberRatings[k.toString()] = v.toDouble();
      });
    } else if (json['rating'] != null && json['rating'] is num) {
      parsedMemberRatings['default'] = (json['rating'] as num).toDouble();
    }

    final Map<String, String> parsedMemberReviews = {};
    if (json['memberReviews'] is Map) {
      (json['memberReviews'] as Map).forEach((k, v) {
        if (v != null) parsedMemberReviews[k.toString()] = v.toString();
      });
    } else if (json['experienceReview'] != null) {
      parsedMemberReviews['default'] = json['experienceReview'].toString();
    }

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
      members: deduplicateMembers((json['members'] as List<dynamic>?)
              ?.map((e) => TripMember.fromJson(e as Map<String, dynamic>))
              .toList() ??
          []),
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
      memberRatings: parsedMemberRatings,
      memberReviews: parsedMemberReviews,
    );
  }
}
