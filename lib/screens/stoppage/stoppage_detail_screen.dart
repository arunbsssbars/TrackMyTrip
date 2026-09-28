import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/stoppage.dart';
import '../../models/trip_audit_log.dart';
import '../../providers/audit_log_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';
import '../expenses/add_expense_screen.dart';
import '../memories/add_memory_dialog.dart';

class StoppageDetailScreen extends ConsumerWidget {
  final String stoppageId;
  final String tripId;

  const StoppageDetailScreen({
    super.key,
    required this.stoppageId,
    required this.tripId,
  });

  void _showInteractivePhotoViewer(
    BuildContext context, {
    required String imagePath,
    required String title,
    String? subtitle,
  }) {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(235),
      builder: (ctx) {
        Widget imageWidget;
        if (imagePath.startsWith('data:image') || (imagePath.length > 200 && !imagePath.contains('/'))) {
          try {
            final cleanBase64 = imagePath.contains(',') ? imagePath.split(',').last : imagePath;
            imageWidget = Image.memory(base64Decode(cleanBase64), fit: BoxFit.contain);
          } catch (_) {
            imageWidget = const Center(child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 60));
          }
        } else if (!kIsWeb && File(imagePath).existsSync()) {
          imageWidget = Image.file(File(imagePath), fit: BoxFit.contain);
        } else {
          imageWidget = Image.network(
            imagePath,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 60),
            ),
          );
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Zoom & Pan Canvas
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.5,
                  child: imageWidget,
                ),
              ),

              // Floating Top Bar with Gradient Backing
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 44, 16, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withAlpha(210), Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle,
                                style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom zoom hint pill
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pinch_rounded, color: Colors.white70, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'Pinch to zoom • Drag to pan',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openAddMemoryDialog(BuildContext context, Stoppage stoppage) {
    showDialog(
      context: context,
      builder: (context) => AddMemoryDialog(tripId: tripId, stoppage: stoppage),
    );
  }

  void _openAddExpenseScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(tripId: tripId, initialStoppageId: stoppageId),
      ),
    );
  }

  void _showEditStoppageDialog(BuildContext context, Stoppage stoppage, WidgetRef ref) {
    final nameController = TextEditingController(text: stoppage.name);
    final notesController = TextEditingController(text: stoppage.notes ?? '');
    String selectedCategory = stoppage.category;
    DateTime arrivedAt = stoppage.arrivedAt;
    DateTime? departedAt = stoppage.departedAt;
    bool isOngoing = stoppage.isOngoing;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Stoppage',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Name Field
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Stoppage Name',
                      hintText: 'e.g. Mountain Cafe, Petrol Pump...',
                      prefixIcon: const Icon(Icons.place_rounded, color: AppTheme.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Category Selector
                  const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: AppConstants.stoppageCategories.map((cat) {
                      final isSelected = selectedCategory == cat;
                      return ChoiceChip(
                        showCheckmark: false,
                        avatar: Icon(
                          AppConstants.getStoppageIcon(cat),
                          size: 14,
                          color: isSelected ? Colors.white : AppTheme.primary,
                        ),
                        label: Text(cat, style: const TextStyle(fontSize: 11)),
                        selected: isSelected,
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : null,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          if (val) setModalState(() => selectedCategory = cat);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Ongoing Toggle
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Currently Stopped (Ongoing)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    subtitle: Text(
                      isOngoing ? 'Stop is active; departure not recorded yet' : 'Stop is finished and departed',
                      style: const TextStyle(fontSize: 11),
                    ),
                    value: isOngoing,
                    activeThumbColor: const Color(0xFF10B981),
                    activeTrackColor: const Color(0xFF10B981).withAlpha(100),
                    onChanged: (val) {
                      setModalState(() {
                        isOngoing = val;
                        if (isOngoing) {
                          departedAt = null;
                        } else {
                          departedAt = DateTime.now();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),

                  // Notes Field
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notes & Highlights (Optional)',
                      hintText: 'Great tea, scenic photo spot...',
                      prefixIcon: const Icon(Icons.notes_rounded, color: AppTheme.secondary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (nameController.text.trim().isEmpty) return;
                        final updated = stoppage.copyWith(
                          name: nameController.text.trim(),
                          category: selectedCategory,
                          notes: notesController.text.trim(),
                          arrivedAt: arrivedAt,
                          departedAt: isOngoing ? null : (departedAt ?? DateTime.now()),
                          clearDepartedAt: isOngoing,
                        );
                        ref.read(allStoppagesProvider.notifier).updateStoppage(updated);
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Stoppage details updated successfully!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteStoppage(BuildContext context, Stoppage stoppage, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Stoppage?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove "${stoppage.name}"? Recorded expenses and memories associated with it will remain.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(allStoppagesProvider.notifier).deleteStoppage(stoppage.id);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🗑️ Stoppage deleted.'), behavior: SnackBarBehavior.floating),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripList = ref.watch(tripListProvider);
    final tripStoppages = ref.watch(tripStoppagesProvider(tripId));
    final allStoppages = ref.watch(allStoppagesProvider);
    final currentStoppages = ref.watch(currentTripStoppagesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Stoppage? matchedStoppage;
    for (final s in tripStoppages) {
      if (s.id == stoppageId) {
        matchedStoppage = s;
        break;
      }
    }
    if (matchedStoppage == null) {
      for (final s in allStoppages) {
        if (s.id == stoppageId) {
          matchedStoppage = s;
          break;
        }
      }
    }
    if (matchedStoppage == null) {
      for (final s in currentStoppages) {
        if (s.id == stoppageId) {
          matchedStoppage = s;
          break;
        }
      }
    }

    if (matchedStoppage == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Stoppage not found')),
      );
    }
    final stoppage = matchedStoppage;

    final trip = tripList.where((t) => t.id == stoppage.tripId).firstOrNull 
        ?? tripList.where((t) => t.id == tripId).firstOrNull 
        ?? ref.watch(currentTripProvider);

    final expenses = ref.watch(stoppageExpensesProvider(stoppageId));
    final memories = ref.watch(stoppageMemoriesProvider(stoppageId));
    final totalSpent = expenses.fold<double>(0, (sum, e) => sum + e.totalAmount);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stoppage.name,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16.5, letterSpacing: -0.3),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${stoppage.category} • Stoppage Details',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 24),
            tooltip: 'Edit Stoppage Details',
            onPressed: () => _showEditStoppageDialog(context, stoppage, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
            tooltip: 'Delete Stoppage',
            onPressed: () => _confirmDeleteStoppage(context, stoppage, ref),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Status & Timing Card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 25 : 8),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Status Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: stoppage.isOngoing
                                ? const Color(0xFF10B981).withAlpha(20)
                                : AppTheme.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            AppConstants.getStoppageIcon(stoppage.category),
                            color: stoppage.isOngoing ? const Color(0xFF10B981) : AppTheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: stoppage.isOngoing ? const Color(0xFF10B981) : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    stoppage.isOngoing ? 'CURRENTLY STOPPED' : 'COMPLETED STOPPAGE',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                      color: stoppage.isOngoing ? const Color(0xFF10B981) : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                stoppage.name,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Arrival & Departure Timings
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.login_rounded, size: 14, color: AppTheme.primary),
                                  SizedBox(width: 4),
                                  Text('Arrival Time', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormatter.formatDateTime(stoppage.arrivedAt),
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        if (stoppage.departedAt != null)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.logout_rounded, size: 14, color: AppTheme.secondary),
                                    SizedBox(width: 4),
                                    Text('Departed & Duration', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${DateFormatter.formatTimeOnly(stoppage.departedAt!)} • ${DateFormatter.formatDuration(stoppage.duration ?? Duration.zero)}',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    // Depart Action Button (If Ongoing)
                    if (stoppage.isOngoing) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            ref.read(allStoppagesProvider.notifier).departStoppage(stoppage.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🚗 Stoppage ended & journey resumed!'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.directions_car_rounded, size: 18),
                          label: const Text(
                            'Depart Stop & Resume Route',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final updated = stoppage.copyWith(clearDepartedAt: true);
                                ref.read(allStoppagesProvider.notifier).updateStoppage(updated);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('🔄 Stoppage reopened as active.'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 15),
                              label: const Text('Reopen Stop', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showEditStoppageDialog(context, stoppage, ref),
                              icon: const Icon(Icons.edit_calendar_rounded, size: 15),
                              label: const Text('Edit Times', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Notes Callout
                    if (stoppage.notes != null && stoppage.notes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.format_quote_rounded, size: 16, color: AppTheme.secondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                stoppage.notes!,
                                style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Quick Add Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _openAddMemoryDialog(context, stoppage),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.secondary.withAlpha(25),
                        foregroundColor: AppTheme.secondary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                      label: const Text('Add Memory', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _openAddExpenseScreen(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary.withAlpha(25),
                        foregroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.receipt_long_rounded, size: 18),
                      label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            // Expenditures Section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Expenditures (${expenses.length})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                  ),
                  Text(
                    CurrencyFormatter.format(totalSpent, currency: trip?.defaultCurrency),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.primary),
                  ),
                ],
              ),
            ),
            if (expenses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
                  ),
                  child: Center(
                    child: Text('No bills logged at this stoppage yet.', style: TextStyle(color: Colors.grey[500], fontSize: 12.5)),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: expenses.length,
                itemBuilder: (context, index) {
                  final expense = expenses[index];
                  final payerName = trip?.getMemberName(expense.paidByMemberId) ?? 'Companion';
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: expense.receiptImagePath != null
                          ? () => _showInteractivePhotoViewer(
                                context,
                                imagePath: expense.receiptImagePath!,
                                title: 'Receipt • ${expense.title}',
                                subtitle: 'Paid by $payerName • ${CurrencyFormatter.format(expense.totalAmount, currency: expense.currency)}',
                              )
                          : null,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.surfaceDark : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppTheme.primary.withAlpha(25),
                              child: Icon(AppConstants.getExpenseIcon(expense.category), color: AppTheme.primary, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          expense.title,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (expense.receiptImagePath != null) ...[
                                        const SizedBox(width: 5),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withAlpha(20),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFF10B981).withAlpha(60), width: 0.8),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.receipt_long_rounded, size: 10, color: Color(0xFF10B981)),
                                              SizedBox(width: 2.5),
                                              Text(
                                                'Receipt',
                                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text('Paid by $payerName • ${expense.category}', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.format(expense.totalAmount, currency: expense.currency),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.primary),
                                ),
                                Text(
                                  '${expense.splits.length} shared',
                                  style: TextStyle(fontSize: 10.5, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                            const SizedBox(width: 2),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey),
                              padding: EdgeInsets.zero,
                              tooltip: 'Expense options',
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              onSelected: (action) async {
                                if (action == 'edit') {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => AddExpenseScreen(
                                        tripId: tripId,
                                        initialExpense: expense,
                                      ),
                                    ),
                                  );
                                } else if (action == 'delete') {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Expense?'),
                                      content: Text('Are you sure you want to delete "${expense.title}"?'),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                          onPressed: () => Navigator.of(ctx).pop(true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    ref.read(allExpensesProvider.notifier).deleteExpense(expense.id);

                                    final trip = ref.read(tripListProvider).where((t) => t.id == tripId).firstOrNull;
                                    final currentMember = trip?.currentUserMember;
                                    ref.read(allAuditLogsProvider.notifier).logAction(
                                      TripAuditLog(
                                        id: const Uuid().v4(),
                                        tripId: tripId,
                                        actionType: 'delete_expense',
                                        itemTitle: expense.title,
                                        performedByMemberId: currentMember?.id ?? 'User',
                                        performedByName: currentMember?.name ?? 'Companion',
                                        timestamp: DateTime.now(),
                                        changeDetails: 'Deleted expense "${expense.title}" (${expense.currency} ${expense.totalAmount.toStringAsFixed(2)})',
                                      ),
                                    );

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Deleted "${expense.title}"'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  height: 38,
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_rounded, size: 16, color: AppTheme.primary),
                                      SizedBox(width: 8),
                                      Text('Edit Expense', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  height: 38,
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete', style: TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

            // Captured Memories Section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Captured Memories (${memories.length})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: -0.3),
              ),
            ),
            if (memories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
                  ),
                  child: Center(
                    child: Text('No memories captured at this stop yet.', style: TextStyle(color: Colors.grey[500], fontSize: 12.5)),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.9,
                ),
                itemCount: memories.length,
                itemBuilder: (context, index) {
                  final memory = memories[index];
                  final uploaderName = trip?.getMemberName(memory.uploadedByMemberId) ?? 'Companion';
                  final myMember = trip?.currentUserMember;
                  final isLiked = myMember != null && memory.likedByMemberIds.contains(myMember.id);

                  Widget imageWidget;
                  if (!kIsWeb && File(memory.mediaPath).existsSync()) {
                    imageWidget = Image.file(File(memory.mediaPath), fit: BoxFit.cover);
                  } else {
                    imageWidget = Image.network(
                      memory.mediaPath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.teal.withAlpha(30),
                        child: const Icon(Icons.photo, size: 36, color: Colors.teal),
                      ),
                    );
                  }

                  return GestureDetector(
                    onTap: () => _showInteractivePhotoViewer(
                      context,
                      imagePath: memory.mediaPath,
                      title: memory.caption != null && memory.caption!.isNotEmpty
                          ? memory.caption!
                          : 'Memory at ${stoppage.name}',
                      subtitle: 'Captured by $uploaderName • ${DateFormatter.formatDateTime(memory.createdAt)}',
                    ),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          imageWidget,
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.transparent, Colors.black.withAlpha(200)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: InkWell(
                              onTap: () {
                                if (myMember != null) {
                                  ref.read(allMemoriesProvider.notifier).toggleLike(memory.id, myMember.id);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                                child: Icon(
                                  isLiked ? Icons.favorite : Icons.favorite_border,
                                  color: isLiked ? Colors.red : Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            right: 8,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (memory.caption != null && memory.caption!.isNotEmpty)
                                  Text(
                                    memory.caption!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                                  ),
                                const SizedBox(height: 1),
                                Text(
                                  'By $uploaderName • ${memory.likedByMemberIds.length} ❤️',
                                  style: const TextStyle(color: Colors.white70, fontSize: 9.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
