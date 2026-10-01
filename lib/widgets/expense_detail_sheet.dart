import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/date_formatter.dart';
import '../core/utils/trip_guard_helper.dart';
import '../models/expense.dart';
import '../models/stoppage.dart';
import '../models/trip.dart';
import '../providers/expense_provider.dart';
import '../screens/expenses/add_expense_screen.dart';

/// Reusable modal sheet displaying complete bill details, splits breakdown,
/// receipt viewer, and edit/delete actions.
class ExpenseDetailSheet extends ConsumerWidget {
  final Trip trip;
  final Expense expense;
  final Stoppage? matchedStop;

  const ExpenseDetailSheet({
    super.key,
    required this.trip,
    required this.expense,
    this.matchedStop,
  });

  static void show(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
    Expense expense, {
    Stoppage? matchedStop,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExpenseDetailSheet(
        trip: trip,
        expense: expense,
        matchedStop: matchedStop,
      ),
    );
  }

  static Widget buildReceiptImage(String path) {
    if (path.startsWith('data:image')) {
      final commaIndex = path.indexOf(',');
      final base64Str = commaIndex != -1 ? path.substring(commaIndex + 1) : path;
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

  static void showReceiptDialog(BuildContext context, Expense expense) {
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
            Center(
              child: InteractiveViewer(
                child: buildReceiptImage(path),
              ),
            ),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(200),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        expense.hasForeignConversion
                            ? '${CurrencyFormatter.format(expense.totalAmount, currency: expense.currency)} (${CurrencyFormatter.format(expense.originalAmount!, currency: expense.originalCurrency)})'
                            : CurrencyFormatter.format(expense.totalAmount, currency: expense.currency),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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

  void _showDeleteDialog(BuildContext context, WidgetRef ref) async {
    final canProceed = await TripGuardHelper.ensureTripOpenForEdit(
      context,
      ref,
      trip,
      actionLabel: 'delete this expense',
    );
    if (!canProceed || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('Are you sure you want to delete "${expense.title}"? This will update the trip balance and notify companions.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(allExpensesProvider.notifier).deleteExpense(expense.id, tripId: trip.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${expense.title}"')),
        );
      }
    }
  }

  void _openEditScreen(BuildContext context, WidgetRef ref) async {
    final canProceed = await TripGuardHelper.ensureTripOpenForEdit(
      context,
      ref,
      trip,
      actionLabel: 'edit this expense',
    );
    if (!canProceed || !context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(
          tripId: trip.id,
          initialExpense: expense,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final payer = trip.getMember(expense.paidByMemberId);
    final payerName = payer?.name ?? 'Unknown';

    return Container(
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      CurrencyFormatter.format(expense.totalAmount, currency: expense.currency),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.primary),
                    ),
                    if (expense.hasForeignConversion)
                      Text(
                        '(${CurrencyFormatter.format(expense.originalAmount!, currency: expense.originalCurrency)})',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                  ],
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_rounded, size: 16, color: AppTheme.primary),
                              SizedBox(width: 8),
                              Text('Paid by:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              payerName,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time_rounded, size: 16, color: AppTheme.secondary),
                              SizedBox(width: 8),
                              Text('Timestamp:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              DateFormatter.formatDateTime(expense.createdAt),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.place_rounded, size: 16, color: Colors.teal),
                              SizedBox(width: 8),
                              Text('Location / Stoppage:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              matchedStop != null ? matchedStop!.name : (expense.locationName ?? 'General Trip'),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      if (expense.hasForeignConversion) ...[
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.currency_exchange_rounded, size: 16, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Original Foreign Bill:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${CurrencyFormatter.format(expense.originalAmount!, currency: expense.originalCurrency)}${expense.exchangeRate != null ? ' @ ${expense.exchangeRate!.toStringAsFixed(2)}' : ''}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Splits Breakdown
                if (!trip.isSolo) ...[
                  const Text('Split Breakdown', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int idx = 0; idx < expense.splits.length; idx++) ...[
                          if (idx > 0) const Divider(height: 1),
                          Builder(
                            builder: (context) {
                              final split = expense.splits[idx];
                              final member = trip.getMember(split.memberId);
                              final name = member?.name ?? 'Member';

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Attached Bill/Receipt Image
                if (expense.receiptImagePath != null) ...[
                  const Text('Attached Bill Photo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => showReceiptDialog(context, expense),
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
                            buildReceiptImage(expense.receiptImagePath!),
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
                          Navigator.of(context).pop();
                          _showDeleteDialog(context, ref);
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
                          Navigator.of(context).pop();
                          _openEditScreen(context, ref);
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
    );
  }
}
