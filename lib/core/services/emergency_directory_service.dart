import 'package:url_launcher/url_launcher.dart';
import '../../models/ice_medical_profile.dart';

class EmergencyHelpline {
  final String title;
  final String number;
  final String description;
  final String region; // 'India', 'USA', 'EU', 'Global'

  const EmergencyHelpline({
    required this.title,
    required this.number,
    required this.description,
    this.region = 'India',
  });
}

class EmergencyDirectoryService {
  static final Map<String, IceMedicalProfile> _iceProfiles = {};

  static const List<EmergencyHelpline> helplines = [
    EmergencyHelpline(title: 'National Emergency', number: '112', description: 'All-in-one emergency dispatch (Police, Fire, Medical)', region: 'India'),
    EmergencyHelpline(title: 'Ambulance / Medical', number: '108', description: 'Immediate medical ambulance assistance', region: 'India'),
    EmergencyHelpline(title: 'Highway Patrol Helpline', number: '1033', description: 'NHAI 24x7 emergency road & towing service', region: 'India'),
    EmergencyHelpline(title: 'Police Control Room', number: '100', description: 'State & highway police emergency', region: 'India'),
    EmergencyHelpline(title: 'Disaster Relief / SAR', number: '1077', description: 'District disaster search and rescue operations', region: 'India'),
    EmergencyHelpline(title: 'USA & Canada 911', number: '911', description: 'Universal emergency service', region: 'USA'),
    EmergencyHelpline(title: 'European Emergency', number: '112', description: 'EU universal emergency helpline', region: 'EU'),
  ];

  /// Saves or updates a member's ICE profile
  static void saveIceProfile(IceMedicalProfile profile) {
    _iceProfiles[profile.memberId] = profile;
  }

  /// Retrieves an ICE profile for a member, providing safe defaults if unset
  static IceMedicalProfile getIceProfile(String memberId, {String memberName = 'Traveler'}) {
    return _iceProfiles[memberId] ?? IceMedicalProfile(
      memberId: memberId,
      memberName: memberName,
      bloodGroup: 'B+',
      allergies: ['Penicillin'],
      emergencyContactName: 'Family Primary Contact',
      emergencyContactPhone: '+91 98765 43210',
    );
  }

  /// Launches the device phone dialer for an emergency helpline
  static Future<bool> dialNumber(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanNumber');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
    } catch (_) {}
    return false;
  }
}
