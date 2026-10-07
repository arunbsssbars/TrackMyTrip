class IceMedicalProfile {
  final String memberId;
  final String memberName;
  final String bloodGroup; // 'A+', 'B+', 'O+', 'AB+', 'A-', 'B-', 'O-', 'AB-'
  final List<String> allergies;
  final List<String> medications;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String? insurancePolicyNumber;
  final String? notes;

  const IceMedicalProfile({
    required this.memberId,
    required this.memberName,
    this.bloodGroup = 'Unknown',
    this.allergies = const [],
    this.medications = const [],
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    this.insurancePolicyNumber,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'memberId': memberId,
    'memberName': memberName,
    'bloodGroup': bloodGroup,
    'allergies': allergies,
    'medications': medications,
    'emergencyContactName': emergencyContactName,
    'emergencyContactPhone': emergencyContactPhone,
    'insurancePolicyNumber': insurancePolicyNumber,
    'notes': notes,
  };

  factory IceMedicalProfile.fromJson(Map<String, dynamic> json) => IceMedicalProfile(
    memberId: json['memberId'] as String,
    memberName: json['memberName'] as String? ?? 'Traveler',
    bloodGroup: json['bloodGroup'] as String? ?? 'Unknown',
    allergies: (json['allergies'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    medications: (json['medications'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    emergencyContactName: json['emergencyContactName'] as String? ?? '',
    emergencyContactPhone: json['emergencyContactPhone'] as String? ?? '',
    insurancePolicyNumber: json['insurancePolicyNumber'] as String?,
    notes: json['notes'] as String?,
  );
}
