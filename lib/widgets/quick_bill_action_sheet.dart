import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:image_picker/image_picker.dart';
import '../core/services/image_compression_service.dart';
import '../core/services/ocr_service.dart';
import '../core/theme/app_theme.dart';
import '../models/trip.dart';
import '../screens/expenses/add_expense_screen.dart';

enum QuickBillAction {
  camera,
  gallery,
  manual,
}

class QuickBillActionSheet extends StatelessWidget {
  final Trip trip;

  const QuickBillActionSheet({
    super.key,
    required this.trip,
  });

  static Future<void> show(BuildContext context, {required Trip trip}) async {
    HapticFeedback.mediumImpact();
    final action = await showModalBottomSheet<QuickBillAction>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => QuickBillActionSheet(trip: trip),
    );

    if (action == null || !context.mounted) return;

    if (action == QuickBillAction.manual) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => AddExpenseScreen(tripId: trip.id),
        ),
      );
      return;
    }

    final ImageSource source = action == QuickBillAction.camera
        ? ImageSource.camera
        : ImageSource.gallery;

    final picked = await ImageCompressionService.pickOptimizedImage(
      picker: ImagePicker(),
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 75,
    );
    if (picked == null || !context.mounted) return;

    // Show transient indicator while extracting OCR data
    final ocr = await OcrService.extractFromReceipt(picked.path);
    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => AddExpenseScreen(
          tripId: trip.id,
          prefillTitle: ocr.title,
          prefillAmount: ocr.amount,
          prefillImagePath: picked.path,
          prefillCategory: ocr.category,
          prefillDescription: ocr.description,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag indicator
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(isDark ? 90 : 60),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(isDark ? 35 : 20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Record Bill or Expense',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Scan receipt or enter bill details for ${trip.title}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Option 1: Scan with Camera
          _buildActionTile(
            context: context,
            action: QuickBillAction.camera,
            icon: Icons.document_scanner_rounded,
            color: const Color(0xFF3B82F6),
            title: 'Scan Receipt with Camera',
            subtitle: 'Instant AI OCR auto-extracts amount, date & merchant',
            isDark: isDark,
          ),

          const SizedBox(height: 10),

          // Option 2: Choose from Gallery
          _buildActionTile(
            context: context,
            action: QuickBillAction.gallery,
            icon: Icons.photo_library_rounded,
            color: const Color(0xFF8B5CF6),
            title: 'Upload from Photos / Gallery',
            subtitle: 'Extract details from existing receipt snapshot or bill PDF',
            isDark: isDark,
          ),

          const SizedBox(height: 10),

          // Option 3: Manual Entry
          _buildActionTile(
            context: context,
            action: QuickBillAction.manual,
            icon: Icons.edit_note_rounded,
            color: const Color(0xFF10B981),
            title: 'Enter Bill Manually',
            subtitle: 'Custom splits, category, currency exchange, notes & tags',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required QuickBillAction action,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Material(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop(action);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(isDark ? 35 : 20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withAlpha(isDark ? 80 : 45),
                    width: 0.8,
                  ),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2.5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
