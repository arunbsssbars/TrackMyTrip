import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/debt_simplifier.dart';
import '../../../models/settlement.dart';
import '../../../models/trip.dart';
import '../../../models/trip_audit_log.dart';
import '../../../providers/audit_log_provider.dart';
import '../../../providers/settlement_provider.dart';

class SettlementTab extends ConsumerStatefulWidget {
  final Trip trip;

  const SettlementTab({super.key, required this.trip});

  @override
  ConsumerState<SettlementTab> createState() => _SettlementTabState();
}

class _SettlementTabState extends ConsumerState<SettlementTab> {
  void _openRecordSettlementDialog(BuildContext context, {DebtTransfer? defaultTransfer, Settlement? existingSettlement}) {
    showDialog(
      context: context,
      builder: (context) => _RecordSettlementDialog(
        trip: widget.trip,
        defaultTransfer: defaultTransfer,
        existingSettlement: existingSettlement,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final netBalances = ref.watch(tripNetBalancesProvider);
    final simplifiedTransfers = ref.watch(simplifiedTransfersProvider);
    final settlements = ref.watch(currentTripSettlementsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
      children: [
        if (widget.trip.isFamily)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withAlpha(60), width: 1.2),
            ),
            child: const Row(
              children: [
                Icon(Icons.family_restroom_rounded, color: Colors.orange, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('👨‍👩‍👧 Family Trip: Pooled Vacation Budget', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(height: 2),
                      Text(
                        'All family expenses are pooled together. Individual settlements or debt transfers are not required.',
                        style: TextStyle(fontSize: 12, color: Colors.orange, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Net Balances Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.trip.isFamily ? 'Family Member Contributions' : 'Individual Balances',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : AppTheme.textMainLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...widget.trip.members.map((member) {
          final balance = netBalances[member.id] ?? 0.0;
          final isPositive = balance > 0.01;
          final isNegative = balance < -0.01;
          final isSettled = !isPositive && !isNegative;

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 1.1),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: member.colorHex != null
                    ? Color(int.parse(member.colorHex!))
                    : AppTheme.primary,
                child: Text(
                  member.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                member.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: Text(
                isSettled
                    ? 'All settled up'
                    : (isPositive ? 'Is owed money by group' : 'Owes money to group'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSettled ? Colors.grey : (isPositive ? Colors.green : Colors.orange),
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSettled
                      ? Colors.grey.withAlpha(20)
                      : (isPositive ? Colors.green.withAlpha(20) : Colors.red.withAlpha(20)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isSettled
                      ? CurrencyFormatter.format(0.0, currency: widget.trip.defaultCurrency)
                      : (isPositive
                          ? '+${CurrencyFormatter.format(balance, currency: widget.trip.defaultCurrency)}'
                          : '-${CurrencyFormatter.format(balance.abs(), currency: widget.trip.defaultCurrency)}'),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isSettled ? Colors.grey : (isPositive ? Colors.green : Colors.red),
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 20),

        // Simplified Debt Transfers (The Solution)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Simplified Transfers to Settle',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : AppTheme.textMainLight,
              ),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.payment_rounded, size: 16),
              label: const Text('Record Custom', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () => _openRecordSettlementDialog(context),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (simplifiedTransfers.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(20),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.green.withAlpha(50)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All companions are completely settled! No outstanding debts.',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          )
        else
          ...simplifiedTransfers.map((transfer) {
            final fromMember = widget.trip.getMember(transfer.fromMemberId);
            final toMember = widget.trip.getMember(transfer.toMemberId);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 5),
              child: Material(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
                elevation: isDark ? 0 : 1.5,
                shadowColor: Colors.amber.withAlpha(25),
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openRecordSettlementDialog(context, defaultTransfer: transfer),
                  borderRadius: BorderRadius.circular(18),
                  splashColor: const Color(0xFFD97706).withAlpha(25),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_circle_right_rounded, color: Color(0xFFD97706), size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                  children: [
                                    TextSpan(
                                      text: fromMember?.name ?? 'Someone',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const TextSpan(text: ' pays '),
                                    TextSpan(
                                      text: toMember?.name ?? 'Someone',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                CurrencyFormatter.format(transfer.amount, currency: widget.trip.defaultCurrency),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          onPressed: () => _openRecordSettlementDialog(context, defaultTransfer: transfer),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Mark Paid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                              SizedBox(width: 3),
                              Icon(Icons.chevron_right_rounded, size: 14, color: Colors.white),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

        const SizedBox(height: 24),

        // Settlement History Section
        if (settlements.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : AppTheme.textMainLight,
                ),
              ),
              Text(
                'Tap to edit',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...settlements.map((s) {
            final payerName = widget.trip.getMemberName(s.payerMemberId);
            final receiverName = widget.trip.getMemberName(s.receiverMemberId);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Material(
                color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                elevation: isDark ? 0 : 1.5,
                shadowColor: Colors.black.withAlpha(isDark ? 40 : 16),
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openRecordSettlementDialog(context, existingSettlement: s),
                  borderRadius: BorderRadius.circular(18),
                  splashColor: AppTheme.primary.withAlpha(22),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 1.1),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.green,
                          child: Icon(Icons.check, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$payerName paid $receiverName', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(
                                '${s.paymentMethod} • ${DateFormatter.formatDateTime(s.settledAt)}${s.notes != null && s.notes!.isNotEmpty ? '\n"${s.notes}"' : ''}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          CurrencyFormatter.format(s.amount, currency: s.currency),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.green),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: isDark ? Colors.grey[400] : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _RecordSettlementDialog extends ConsumerStatefulWidget {
  final Trip trip;
  final DebtTransfer? defaultTransfer;
  final Settlement? existingSettlement;

  const _RecordSettlementDialog({
    required this.trip,
    this.defaultTransfer,
    this.existingSettlement,
  });

  @override
  ConsumerState<_RecordSettlementDialog> createState() => _RecordSettlementDialogState();
}

class _RecordSettlementDialogState extends ConsumerState<_RecordSettlementDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _payerId;
  late String _receiverId;
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  late String _paymentMethod;
  bool _isAdvance = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingSettlement;
    final transfer = widget.defaultTransfer;

    if (existing != null) {
      _payerId = existing.payerMemberId;
      _receiverId = existing.receiverMemberId;
      _amountController = TextEditingController(text: existing.amount.toStringAsFixed(2));
      _notesController = TextEditingController(text: existing.notes ?? '');
      _paymentMethod = existing.paymentMethod;
      _isAdvance = existing.isAdvance;
    } else {
      _payerId = transfer?.fromMemberId ?? (widget.trip.members.isNotEmpty ? widget.trip.members.first.id : '');
      _receiverId = transfer?.toMemberId ?? (widget.trip.members.length > 1 ? widget.trip.members[1].id : '');
      _amountController = TextEditingController(text: transfer != null ? transfer.amount.toStringAsFixed(2) : '');
      _notesController = TextEditingController();
      _paymentMethod = 'Cash / Direct';
      _isAdvance = false;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveSettlement() {
    if (!_formKey.currentState!.validate()) return;
    if (_payerId == _receiverId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payer and receiver cannot be the same person')),
      );
      return;
    }

    final amount = double.parse(_amountController.text.trim());
    final currentMember = widget.trip.currentUserMember;

    if (widget.existingSettlement != null) {
      final updated = widget.existingSettlement!.copyWith(
        payerMemberId: _payerId,
        receiverMemberId: _receiverId,
        amount: amount,
        paymentMethod: _paymentMethod,
        notes: _notesController.text.trim(),
        isAdvance: _isAdvance,
      );
      ref.read(allSettlementsProvider.notifier).updateSettlement(updated);

      ref.read(allAuditLogsProvider.notifier).logAction(
        TripAuditLog(
          id: const Uuid().v4(),
          tripId: widget.trip.id,
          actionType: 'edit_settlement',
          itemTitle: 'Payment of ${CurrencyFormatter.format(amount, currency: widget.trip.defaultCurrency)}',
          performedByMemberId: currentMember?.id ?? 'User',
          performedByName: currentMember?.name ?? 'Companion',
          timestamp: DateTime.now(),
          reason: 'Payment details modified',
          changeDetails: '${widget.trip.getMemberName(_payerId)} -> ${widget.trip.getMemberName(_receiverId)}: ${CurrencyFormatter.format(amount, currency: widget.trip.defaultCurrency)}',
        ),
      );
    } else {
      final newSettlement = Settlement(
        id: const Uuid().v4(),
        tripId: widget.trip.id,
        payerMemberId: _payerId,
        receiverMemberId: _receiverId,
        amount: amount,
        currency: widget.trip.defaultCurrency,
        settledAt: DateTime.now(),
        paymentMethod: _paymentMethod,
        notes: _notesController.text.trim(),
        isAdvance: _isAdvance,
      );
      ref.read(allSettlementsProvider.notifier).addSettlement(newSettlement);

      ref.read(allAuditLogsProvider.notifier).logAction(
        TripAuditLog(
          id: const Uuid().v4(),
          tripId: widget.trip.id,
          actionType: 'create_settlement',
          itemTitle: 'Payment of ${CurrencyFormatter.format(amount, currency: widget.trip.defaultCurrency)}',
          performedByMemberId: currentMember?.id ?? 'User',
          performedByName: currentMember?.name ?? 'Companion',
          timestamp: DateTime.now(),
          reason: 'Debt settled',
          changeDetails: '${widget.trip.getMemberName(_payerId)} paid ${widget.trip.getMemberName(_receiverId)}',
        ),
      );
    }

    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  void _deleteSettlement() {
    if (widget.existingSettlement == null) return;
    ref.read(allSettlementsProvider.notifier).deleteSettlement(widget.existingSettlement!.id);

    final currentMember = widget.trip.currentUserMember;
    ref.read(allAuditLogsProvider.notifier).logAction(
      TripAuditLog(
        id: const Uuid().v4(),
        tripId: widget.trip.id,
        actionType: 'delete_settlement',
        itemTitle: 'Payment of ${CurrencyFormatter.format(widget.existingSettlement!.amount, currency: widget.trip.defaultCurrency)}',
        performedByMemberId: currentMember?.id ?? 'User',
        performedByName: currentMember?.name ?? 'Companion',
        timestamp: DateTime.now(),
        reason: 'Payment cancelled / deleted',
        changeDetails: 'Deleted ${CurrencyFormatter.format(widget.existingSettlement!.amount, currency: widget.trip.defaultCurrency)}',
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingSettlement != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(isEditing ? 'Edit Payment' : 'Record Payment', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _deleteSettlement,
            ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _payerId.isNotEmpty ? _payerId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Payer (Who Paid)', prefixIcon: Icon(Icons.person)),
                  items: widget.trip.members.map((m) {
                    return DropdownMenuItem(value: m.id, child: Text(m.name, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _payerId = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _receiverId.isNotEmpty ? _receiverId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Receiver (Who Got Paid)', prefixIcon: Icon(Icons.person_outline)),
                  items: widget.trip.members.map((m) {
                    return DropdownMenuItem(value: m.id, child: Text(m.name, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _receiverId = val);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount Paid',
                    prefixText: '${CurrencyFormatter.getCurrencySymbol(widget.trip.defaultCurrency)} ',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter amount';
                    final parsed = double.tryParse(val.trim());
                    if (parsed == null || parsed <= 0) return 'Enter valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Payment Method', prefixIcon: Icon(Icons.payment)),
                  items: ['Cash / Direct', 'UPI / Google Pay', 'Venmo / PayPal', 'Bank Transfer', 'Other'].map((method) {
                    return DropdownMenuItem(value: method, child: Text(method, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _paymentMethod = val);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'e.g. Settle lunch & fuel',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Initial Advance Contribution'),
                  subtitle: const Text('Mark this as an upfront deposit to the trip organizer', style: TextStyle(fontSize: 11)),
                  value: _isAdvance,
                  activeColor: AppTheme.primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setState(() => _isAdvance = val);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saveSettlement,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          child: Text(isEditing ? 'Save Changes' : 'Record Payment'),
        ),
      ],
    );
  }
}
