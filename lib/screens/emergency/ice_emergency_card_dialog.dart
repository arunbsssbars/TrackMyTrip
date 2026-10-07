import 'package:flutter/material.dart';
import '../../core/services/emergency_directory_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/ice_medical_profile.dart';

class IceEmergencyCardDialog extends StatelessWidget {
  final IceMedicalProfile profile;

  const IceEmergencyCardDialog({
    super.key,
    required this.profile,
  });

  static Future<void> show(BuildContext context, {required IceMedicalProfile profile}) {
    return showDialog(
      context: context,
      builder: (ctx) => IceEmergencyCardDialog(profile: profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 650),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.medical_services_rounded, color: Colors.red, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ICE Medical Rescue Card',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        profile.memberName,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Dismiss',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 20),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Blood Group & Primary Info Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withAlpha(50)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              profile.bloodGroup,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Blood Group', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                Text(
                                  profile.allergies.isNotEmpty
                                      ? 'Allergies: ${profile.allergies.join(", ")}'
                                      : 'No known drug allergies',
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Primary Emergency Contact
                    const Text('Primary Emergency Contact', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withAlpha(40)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 20, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(profile.emergencyContactName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                Text(profile.emergencyContactPhone, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          IconButton.filled(
                            icon: const Icon(Icons.phone, size: 18),
                            tooltip: 'Call Emergency Contact',
                            style: IconButton.styleFrom(backgroundColor: Colors.green),
                            onPressed: () => EmergencyDirectoryService.dialNumber(profile.emergencyContactPhone),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Emergency Dispatch Helplines
                    const Text('Direct Rescue Helplines', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...EmergencyDirectoryService.helplines.take(4).map((h) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withAlpha(30),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  h.number,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(h.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                    Text(h.description, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.call, color: Colors.green, size: 20),
                                tooltip: 'Dial ${h.number}',
                                onPressed: () => EmergencyDirectoryService.dialNumber(h.number),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // SOS Broadcast Callout
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => EmergencyDirectoryService.dialNumber('112'),
                icon: const Icon(Icons.emergency_rounded, color: Colors.white),
                label: const Text('Dial 112 National Rescue', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
