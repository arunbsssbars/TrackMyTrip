import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/expense.dart';
import '../../../models/stoppage.dart';
import '../../../models/trip.dart';
import '../../../models/trip_audit_log.dart';
import '../../../providers/audit_log_provider.dart';
import '../../../providers/expense_provider.dart';
import '../../../providers/stoppage_provider.dart';
import '../../../providers/trip_provider.dart';
import '../../expense/add_expense_screen.dart';
import '../audit_log_sheet.dart';
import '../../../core/utils/trip_guard_helper.dart';

class ExpensesTab extends ConsumerStatefulWidget {
  final Trip trip;

  const ExpensesTab({super.key, required this.trip});

  @override
  ConsumerState<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends ConsumerState<ExpensesTab> {
  String? _selectedCategoryFilter;

  void _openAddExpenseScreen(BuildContext context, {Expense? expenseToEdit}) async {
    final canProceed = await TripGuardHelper.ensureTripOpenForEdit(
      context,
      ref,
      widget.trip,
      actionLabel: expenseToEdit != null ? 'edit this expense' : 'record an expense',
    );
    if (!canProceed || !context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(
          tripId: widget.trip.id,
          initialExpense: expenseToEdit,
        ),
      ),
    );
  }

  void _showDeleteExpenseDialog(BuildContext context, Expense expense) async {
    final canProceed = await TripGuardHelper.ensureTripOpenForEdit(
      context,
      ref,
      widget.trip,
      actionLabel: 'delete this expense',
    );
    if (!canProceed || !context.mounted) return;

    final reasonController = TextEditingController(text: 'Duplicate entry');
    final quickReasons = [
      'Duplicate entry',
      'Incorrect amount',
      'Maya paid directly',
      'Cancelled activity',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Delete Expense Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete "${expense.title}" (${CurrencyFormatter.format(expense.totalAmount, currency: expense.currency)})?',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                'This will recalculate all companion balances. Please select or enter the remark for complete team transparency:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: quickReasons.map((r) {
                  final isSelected = reasonController.text == r;
                  return ChoiceChip(
                    showCheckmark: false,
                    label: Text(r, style: const TextStyle(fontSize: 11)),
                    selected: isSelected,
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : null),
                    onSelected: (selected) {
                      if (selected) {
                        setDialogState(() => reasonController.text = r);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Custom Remark / Note (Optional)',
                  hintText: 'e.g. Maya already paid for this separately',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                final reason = reasonController.text.trim();
                Navigator.of(ctx).pop();

                ref.read(allExpensesProvider.notifier).deleteExpense(expense.id);

                final currentMember = widget.trip.currentUserMember;
                ref.read(allAuditLogsProvider.notifier).logAction(
                  TripAuditLog(
                    id: const Uuid().v4(),
                    tripId: widget.trip.id,
                    actionType: 'delete_expense',
                    itemTitle: expense.title,
                    performedByMemberId: currentMember?.id ?? 'User',
                    performedByName: currentMember?.name ?? 'Companion',
                    timestamp: DateTime.now(),
                    reason: reason.isNotEmpty ? reason : 'No specific reason given',
                    changeDetails: 'Deleted ${CurrencyFormatter.format(expense.totalAmount, currency: expense.currency)}',
                  ),
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🗑️ "${expense.title}" deleted & recorded in Trust History.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Delete Bill', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptImage(String path) {
    if (path.startsWith('data:image')) {
      final base64Str = path.split(',').last;
      return Image.memory(
        base64Decode(base64Str),
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      );
    } else if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      );
    } else if (!kIsWeb) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      );
    } else {
      return const Center(child: Icon(Icons.receipt_long, color: Colors.grey));
    }
  }

  void _showReceiptDialog(BuildContext context, Expense expense) {
    if (expense.receiptImagePath == null) return;
    HapticFeedback.selectionClick();
    final path = expense.receiptImagePath!;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Full screen zoomable image
            Center(
              child: InteractiveViewer(
                child: _buildReceiptImage(path),
              ),
            ),

            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withAlpha(200), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Receipt • ${expense.title}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom info bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withAlpha(200)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    // Amount badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(200),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        CurrencyFormatter.format(expense.totalAmount, currency: expense.currency),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(160),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AppConstants.getExpenseIcon(expense.category),
                            color: Colors.white70,
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            expense.category,
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.zoom_in_rounded, color: Colors.white54, size: 16),
                    const SizedBox(width: 4),
                    const Text(
                      'Pinch to zoom',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExpenseDetailSheet(BuildContext context, Expense expense, Stoppage? matchedStop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final payer = widget.trip.getMember(expense.paidByMemberId);
    final payerName = payer?.name ?? 'Unknown';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(AppConstants.getExpenseIcon(expense.category), color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.title,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          expense.category,
                          style: const TextStyle(fontSize: 12, color: AppTheme.secondary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(expense.totalAmount, currency: expense.currency),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.primary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  // Meta Card (Payer, Date, Stoppage)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_rounded, size: 16, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            const Text('Paid by:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const Spacer(),
                            Text(payerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 16, color: AppTheme.secondary),
                            const SizedBox(width: 8),
                            const Text('Timestamp:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const Spacer(),
                            Text(
                              DateFormatter.formatDateTime(expense.createdAt),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.place_rounded, size: 16, color: Colors.teal),
                            const SizedBox(width: 8),
                            const Text('Location / Stoppage:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const Spacer(),
                            Flexible(
                              child: Text(
                                matchedStop != null ? matchedStop.name : (expense.locationName ?? 'General Trip'),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Splits Breakdown
                  if (!widget.trip.isSolo) ...[
                    const Text('Split Breakdown', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: expense.splits.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final split = expense.splits[idx];
                          final member = widget.trip.getMember(split.memberId);
                          final name = member?.name ?? 'Member';

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: split.isIncluded ? AppTheme.primary.withAlpha(30) : Colors.grey.withAlpha(30),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: split.isIncluded ? AppTheme.primary : Colors.grey,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: split.isIncluded ? null : Colors.grey,
                                    ),
                                  ),
                                ),
                                if (split.isIncluded)
                                  Text(
                                    CurrencyFormatter.format(split.allocatedAmount, currency: expense.currency),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  )
                                else
                                  const Text('Excluded', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Attached Bill/Receipt Image
                  if (expense.receiptImagePath != null) ...[
                    const Text('Attached Bill Photo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _showReceiptDialog(context, expense),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.teal.withAlpha(80)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildReceiptImage(expense.receiptImagePath!),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(180),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text('Tap to View Full Bill', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Notes (if any)
                  if (expense.notes != null && expense.notes!.isNotEmpty) ...[
                    const Text('Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '"${expense.notes}"',
                        style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Action Buttons: Edit and Delete
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _showDeleteExpenseDialog(context, expense);
                          },
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                          label: const Text('Delete Bill', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Colors.red, width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _openAddExpenseScreen(context, expenseToEdit: expense);
                          },
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: const Text('Edit Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetBudgetDialog(BuildContext context) {
    final controller = TextEditingController(
      text: widget.trip.budget != null ? widget.trip.budget!.toStringAsFixed(0) : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Set Trip Budget', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set a spending goal for this trip to track your remaining balance:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Trip Budget',
                prefixText: '${CurrencyFormatter.getCurrencySymbol(widget.trip.defaultCurrency)} ',
                hintText: 'e.g. 1000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              final updated = widget.trip.copyWith(budget: val);
              ref.read(tripListProvider.notifier).updateTrip(updated);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save Budget'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(currentTripExpensesProvider);
    final stoppages = ref.watch(currentTripStoppagesProvider);
    final totalSpent = ref.watch(currentTripTotalSpentProvider);
    final auditLogs = ref.watch(currentTripAuditLogsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trip = ref.watch(tripListProvider).firstWhere((t) => t.id == widget.trip.id, orElse: () => widget.trip);
    final budget = trip.budget;

    final filteredExpenses = _selectedCategoryFilter == null
        ? expenses
        : expenses.where((e) => e.category == _selectedCategoryFilter).toList();

    return Column(
      children: [
        // Expenditure Summary & Budget Card
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL EXPENDITURE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: isDark ? Colors.grey[400] : AppTheme.textMutedLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              CurrencyFormatter.format(totalSpent, currency: trip.defaultCurrency),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () => _openAddExpenseScreen(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),

                // Budget Progress Section
                if (budget != null && budget > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Budget: ${CurrencyFormatter.format(budget, currency: trip.defaultCurrency)}',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          totalSpent > budget
                              ? 'Over by ${CurrencyFormatter.format(totalSpent - budget, currency: trip.defaultCurrency)}'
                              : 'Remaining: ${CurrencyFormatter.format(budget - totalSpent, currency: trip.defaultCurrency)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: totalSpent > budget ? Colors.red : Colors.green,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (totalSpent / budget).clamp(0.0, 1.0),
                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        totalSpent > budget ? Colors.red : AppTheme.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.transparent,
                    child: Ink(
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primary.withAlpha(45), width: 1),
                      ),
                      child: InkWell(
                        onTap: () => _showSetBudgetDialog(context),
                        borderRadius: BorderRadius.circular(8),
                        splashColor: AppTheme.primary.withAlpha(30),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          child: Row(
                            children: [
                              Icon(Icons.add_circle_outline_rounded, size: 14, color: AppTheme.primary),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Set a trip budget target to track remaining balance',
                                  style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                // Trust & Audit History Bar
                const SizedBox(height: 10),
                Material(
                  color: Colors.transparent,
                  child: Ink(
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primary.withAlpha(45), width: 1.1),
                    ),
                    child: InkWell(
                      onTap: () => AuditLogSheet.show(context, widget.trip),
                      borderRadius: BorderRadius.circular(10),
                      splashColor: AppTheme.primary.withAlpha(30),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.verified_user_rounded, size: 14, color: AppTheme.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Trust & Audit History (${auditLogs.length} logs)',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                ),
                              ],
                            ),
                            const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.primary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Category Filter Chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  showCheckmark: false,
                  label: const Text('All Bills', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  selected: _selectedCategoryFilter == null,
                  selectedColor: AppTheme.primary,
                  labelStyle: TextStyle(color: _selectedCategoryFilter == null ? Colors.white : null),
                  onSelected: (_) => setState(() => _selectedCategoryFilter = null),
                ),
                const SizedBox(width: 6),
                ...AppConstants.expenseCategories.map((cat) {
                  final isSelected = _selectedCategoryFilter == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      showCheckmark: false,
                      avatar: Icon(AppConstants.getExpenseIcon(cat), size: 14, color: isSelected ? Colors.white : AppTheme.primary),
                      label: Text(cat, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      selected: isSelected,
                      selectedColor: AppTheme.primary,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : null),
                      onSelected: (_) => setState(() => _selectedCategoryFilter = cat),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // Expense List
        Expanded(
          child: filteredExpenses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        _selectedCategoryFilter == null ? 'No Bills Logged Yet' : 'No $_selectedCategoryFilter Bills',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      const Text('Track shared food, gas, tickets, and activities at each stop.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                  itemCount: filteredExpenses.length,
                  itemBuilder: (context, index) {
                    final expense = filteredExpenses[index];
                    final payer = widget.trip.getMember(expense.paidByMemberId);
                    final payerName = payer?.name ?? 'Unknown';

                    Stoppage? matchedStop;
                    if (expense.stoppageId != null) {
                      for (final s in stoppages) {
                        if (s.id == expense.stoppageId) {
                          matchedStop = s;
                          break;
                        }
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 5.5),
                      child: Material(
                        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                        elevation: isDark ? 0 : 2,
                        shadowColor: Colors.black.withAlpha(isDark ? 45 : 18),
                        borderRadius: BorderRadius.circular(18),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _showExpenseDetailSheet(context, expense, matchedStop),
                          borderRadius: BorderRadius.circular(18),
                          splashColor: AppTheme.primary.withAlpha(22),
                          highlightColor: AppTheme.primary.withAlpha(12),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                                width: 1.1,
                              ),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withAlpha(20),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(AppConstants.getExpenseIcon(expense.category), color: AppTheme.primary, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            expense.title,
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.2),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: 'Paid by ',
                                                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                                ),
                                                TextSpan(
                                                  text: payerName,
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                ),
                                                TextSpan(
                                                  text: ' • ${DateFormatter.formatRelativeOrTime(expense.createdAt)}',
                                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                                ),
                                              ],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          CurrencyFormatter.format(expense.totalAmount, currency: expense.currency),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                            letterSpacing: -0.3,
                                            color: isDark ? Colors.white : AppTheme.textMainLight,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 19,
                                          color: isDark ? Colors.grey[400] : const Color(0xFF94A3B8),
                                        ),
                                        PopupMenuButton<String>(
                                          icon: Icon(Icons.more_vert_rounded, size: 18, color: isDark ? Colors.grey[400] : const Color(0xFF94A3B8)),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onSelected: (val) {
                                            if (val == 'details') {
                                              _showExpenseDetailSheet(context, expense, matchedStop);
                                            } else if (val == 'view_receipt') {
                                              _showReceiptDialog(context, expense);
                                            } else if (val == 'edit') {
                                              _openAddExpenseScreen(context, expenseToEdit: expense);
                                            } else if (val == 'delete') {
                                              _showDeleteExpenseDialog(context, expense);
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(
                                              value: 'details',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 18),
                                                  SizedBox(width: 8),
                                                  Text('View Details'),
                                                ],
                                              ),
                                            ),
                                            if (expense.receiptImagePath != null)
                                              const PopupMenuItem(
                                                value: 'view_receipt',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.receipt_long_rounded, color: Colors.teal, size: 18),
                                                    SizedBox(width: 8),
                                                    Text('View Attached Bill'),
                                                  ],
                                                ),
                                              ),
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit_outlined, color: Colors.amber, size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Edit Expense'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Delete Expense', style: TextStyle(color: Colors.red)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Divider(height: 1),
                                const SizedBox(height: 8),

                                // Stoppage Anchor tag + Bill Badge + Splits Info
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (matchedStop != null)
                                            Flexible(
                                              child: Material(
                                                color: Colors.transparent,
                                                child: Ink(
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.secondary.withAlpha(isDark ? 28 : 18),
                                                    borderRadius: BorderRadius.circular(7),
                                                    border: Border.all(color: AppTheme.secondary.withAlpha(isDark ? 80 : 50), width: 0.9),
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.place_rounded, size: 12, color: AppTheme.secondary),
                                                        const SizedBox(width: 3.5),
                                                        Flexible(
                                                          child: Text(
                                                            matchedStop.name,
                                                            style: const TextStyle(
                                                              fontSize: 10.5,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppTheme.secondary,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                          else if (expense.locationName != null && expense.locationName!.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(right: 6),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.secondary.withAlpha(isDark ? 28 : 18),
                                                  borderRadius: BorderRadius.circular(7),
                                                  border: Border.all(color: AppTheme.secondary.withAlpha(isDark ? 80 : 50), width: 0.9),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.place_rounded, size: 12, color: AppTheme.secondary),
                                                    const SizedBox(width: 3.5),
                                                    Flexible(
                                                      child: Text(
                                                        expense.locationName!,
                                                        style: const TextStyle(
                                                          fontSize: 10.5,
                                                          fontWeight: FontWeight.bold,
                                                          color: AppTheme.secondary,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          else
                                            Text('General Trip', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                          if (expense.receiptImagePath != null) ...[
                                            const SizedBox(width: 6),
                                            Material(
                                              color: Colors.transparent,
                                              child: Ink(
                                                decoration: BoxDecoration(
                                                  color: Colors.teal.withAlpha(isDark ? 30 : 20),
                                                  borderRadius: BorderRadius.circular(7),
                                                  border: Border.all(color: Colors.teal.withAlpha(isDark ? 80 : 50), width: 1),
                                                ),
                                                child: InkWell(
                                                  onTap: () => _showReceiptDialog(context, expense),
                                                  borderRadius: BorderRadius.circular(7),
                                                  splashColor: Colors.teal.withAlpha(40),
                                                  child: const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.receipt_long_rounded, size: 12, color: Colors.teal),
                                                        SizedBox(width: 3.5),
                                                        Text(
                                                          'Receipt 🔍',
                                                          style: TextStyle(
                                                            fontSize: 10.5,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.teal,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.trip.isSolo
                                          ? '🎒 Solo Log'
                                          : widget.trip.isFamily
                                              ? '👨‍👩‍👧 Family Pool'
                                              : 'Split across ${expense.splits.where((s) => s.isIncluded).length} companions',
                                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
