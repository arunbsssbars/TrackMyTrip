import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/expense.dart';
import '../../models/expense_split.dart';
import '../../models/trip_member.dart';
import '../../models/trip_audit_log.dart';
import '../../providers/audit_log_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String? initialStoppageId;
  final Expense? initialExpense;

  const AddExpenseScreen({
    super.key,
    required this.tripId,
    this.initialStoppageId,
    this.initialExpense,
  });

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedStoppageId;
  String _selectedCategory = AppConstants.expenseCategories.first;
  String? _paidByMemberId;
  SplitType _splitType = SplitType.equal;
  String? _receiptImagePath;

  // Curated sample receipts for 1-tap testing
  static const List<String> _sampleReceipts = [
    'https://images.unsplash.com/photo-1554415707-9e49016a3e65?w=800&q=80',
    'https://images.unsplash.com/photo-1559526324-4b87b5e36e44?w=800&q=80',
    'https://images.unsplash.com/photo-1550547660-d9450f859349?w=800&q=80',
  ];

  // Split state per member
  final Map<String, bool> _equalIncluded = {};
  final Map<String, TextEditingController> _exactControllers = {};
  final Map<String, TextEditingController> _percentControllers = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialExpense != null) {
      final exp = widget.initialExpense!;
      _titleController.text = exp.title;
      _amountController.text = exp.totalAmount.toStringAsFixed(2);
      _notesController.text = exp.notes ?? '';
      _selectedStoppageId = exp.stoppageId;
      _selectedCategory = exp.category;
      _paidByMemberId = exp.paidByMemberId;
      _splitType = exp.splitType;
      _receiptImagePath = exp.receiptImagePath;

      for (final s in exp.splits) {
        _equalIncluded[s.memberId] = s.isIncluded;
        _exactControllers[s.memberId] = TextEditingController(text: s.allocatedAmount.toStringAsFixed(2));
        _percentControllers[s.memberId] = TextEditingController(text: (s.percentage ?? 0).toStringAsFixed(1));
      }
    } else {
      _selectedStoppageId = widget.initialStoppageId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    for (final c in _exactControllers.values) {
      c.dispose();
    }
    for (final c in _percentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initMemberSplits(List<TripMember> members) {
    if (_paidByMemberId == null && members.isNotEmpty) {
      TripMember? me;
      for (final m in members) {
        if (m.isCurrentUser) {
          me = m;
          break;
        }
      }
      _paidByMemberId = (me ?? members.first).id;
    }

    for (final member in members) {
      _equalIncluded.putIfAbsent(member.id, () => true);
      _exactControllers.putIfAbsent(member.id, () => TextEditingController(text: '0.00'));
      _percentControllers.putIfAbsent(
        member.id,
        () => TextEditingController(text: (100 / members.length).toStringAsFixed(1)),
      );
    }
  }

  List<ExpenseSplit> _buildSplits(double totalAmount, List<TripMember> members) {
    final List<ExpenseSplit> splits = [];

    switch (_splitType) {
      case SplitType.equal:
        final includedCount = _equalIncluded.values.where((v) => v).length;
        final perPerson = includedCount > 0 ? (totalAmount / includedCount) : 0.0;
        for (final member in members) {
          final isInc = _equalIncluded[member.id] ?? false;
          splits.add(
            ExpenseSplit(
              memberId: member.id,
              allocatedAmount: isInc ? perPerson : 0.0,
              isIncluded: isInc,
            ),
          );
        }
        break;

      case SplitType.exact:
        for (final member in members) {
          final val = double.tryParse(_exactControllers[member.id]?.text ?? '0') ?? 0.0;
          splits.add(
            ExpenseSplit(
              memberId: member.id,
              allocatedAmount: val,
              isIncluded: val > 0,
            ),
          );
        }
        break;

      case SplitType.percentage:
        for (final member in members) {
          final pct = double.tryParse(_percentControllers[member.id]?.text ?? '0') ?? 0.0;
          final val = (pct / 100.0) * totalAmount;
          splits.add(
            ExpenseSplit(
              memberId: member.id,
              allocatedAmount: val,
              percentage: pct,
              isIncluded: pct > 0,
            ),
          );
        }
        break;
      case SplitType.shares:
        break;
    }

    return splits;
  }

  Future<void> _pickReceiptImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (picked != null) {
        if (kIsWeb) {
          final bytes = await picked.readAsBytes();
          final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
          setState(() => _receiptImagePath = base64String);
        } else {
          setState(() => _receiptImagePath = picked.path);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach image: $e')),
        );
      }
    }
  }

  Widget _buildReceiptThumbnail(String path) {
    if (path.startsWith('data:image')) {
      final base64Data = path.split(',').last;
      return Image.memory(base64Decode(base64Data), fit: BoxFit.cover);
    } else if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(path, fit: BoxFit.cover);
    } else if (!kIsWeb) {
      return Image.file(File(path), fit: BoxFit.cover);
    } else {
      return const Center(child: Icon(Icons.receipt_long_rounded, size: 36, color: AppTheme.primary));
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final totalAmount = double.tryParse(_amountController.text.trim());
    if (totalAmount == null || totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid expense amount')),
      );
      return;
    }

    final trip = ref.read(currentTripProvider);
    if (trip == null) return;

    final splits = _buildSplits(totalAmount, trip.members);

    // Validate sum for exact & percentage splits
    if (_splitType == SplitType.exact) {
      final sum = splits.fold<double>(0, (acc, s) => acc + s.allocatedAmount);
      if ((sum - totalAmount).abs() > 0.05) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sum of exact shares (${CurrencyFormatter.format(sum, currency: trip.defaultCurrency)}) must equal total (${CurrencyFormatter.format(totalAmount, currency: trip.defaultCurrency)})',
            ),
          ),
        );
        return;
      }
    }

    final isEditing = widget.initialExpense != null;

    if (isEditing) {
      final oldExp = widget.initialExpense!;
      final updatedExpense = Expense(
        id: oldExp.id,
        tripId: widget.tripId,
        stoppageId: _selectedStoppageId,
        title: _titleController.text.trim(),
        totalAmount: totalAmount,
        currency: trip.defaultCurrency,
        category: _selectedCategory,
        paidByMemberId: _paidByMemberId ?? trip.members.first.id,
        splitType: _splitType,
        splits: splits,
        receiptImagePath: _receiptImagePath,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        createdAt: oldExp.createdAt,
      );

      final stoppages = ref.read(currentTripStoppagesProvider);

      // Auto-detect and record all change details
      final List<String> changeList = [];
      if (oldExp.title != updatedExpense.title) {
        changeList.add('Title: "${oldExp.title}" ➔ "${updatedExpense.title}"');
      }
      if ((oldExp.totalAmount - updatedExpense.totalAmount).abs() > 0.01) {
        changeList.add('Amount: ${CurrencyFormatter.format(oldExp.totalAmount, currency: trip.defaultCurrency)} ➔ ${CurrencyFormatter.format(updatedExpense.totalAmount, currency: trip.defaultCurrency)}');
      }
      if (oldExp.paidByMemberId != updatedExpense.paidByMemberId) {
        final oldPayer = trip.getMember(oldExp.paidByMemberId)?.name ?? 'Unknown';
        final newPayer = trip.getMember(updatedExpense.paidByMemberId)?.name ?? 'Unknown';
        changeList.add('Payer: $oldPayer ➔ $newPayer');
      }
      if (oldExp.category != updatedExpense.category) {
        changeList.add('Category: ${oldExp.category} ➔ ${updatedExpense.category}');
      }
      if (oldExp.stoppageId != updatedExpense.stoppageId) {
        final oldStop = stoppages.where((s) => s.id == oldExp.stoppageId).firstOrNull?.name ?? 'General Trip';
        final newStop = stoppages.where((s) => s.id == updatedExpense.stoppageId).firstOrNull?.name ?? 'General Trip';
        changeList.add('Stop: $oldStop ➔ $newStop');
      }
      if (changeList.isEmpty) {
        changeList.add('Updated splits or invoice details');
      }

      final changeDesc = changeList.join(' • ');

      ref.read(allExpensesProvider.notifier).updateExpense(updatedExpense);

      final currentMember = trip.currentUserMember;
      ref.read(allAuditLogsProvider.notifier).logAction(
        TripAuditLog(
          id: const Uuid().v4(),
          tripId: widget.tripId,
          actionType: 'edit_expense',
          itemTitle: updatedExpense.title,
          performedByMemberId: currentMember?.id ?? 'User',
          performedByName: currentMember?.name ?? 'Companion',
          timestamp: DateTime.now(),
          reason: 'Updated via bill edit',
          changeDetails: changeDesc,
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Updated "${updatedExpense.title}" & logged in Trust History.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop();
    } else {
      final newExpense = Expense(
        id: const Uuid().v4(),
        tripId: widget.tripId,
        stoppageId: _selectedStoppageId,
        title: _titleController.text.trim(),
        totalAmount: totalAmount,
        currency: trip.defaultCurrency,
        category: _selectedCategory,
        paidByMemberId: _paidByMemberId ?? trip.members.first.id,
        splitType: _splitType,
        splits: splits,
        receiptImagePath: _receiptImagePath,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        createdAt: DateTime.now(),
      );

      ref.read(allExpensesProvider.notifier).addExpense(newExpense);

      // Log creation
      final currentMember = trip.currentUserMember;
      ref.read(allAuditLogsProvider.notifier).logAction(
        TripAuditLog(
          id: const Uuid().v4(),
          tripId: widget.tripId,
          actionType: 'create_expense',
          itemTitle: newExpense.title,
          performedByMemberId: currentMember?.id ?? 'User',
          performedByName: currentMember?.name ?? 'Companion',
          timestamp: DateTime.now(),
          changeDetails: 'Added bill of ${CurrencyFormatter.format(newExpense.totalAmount, currency: trip.defaultCurrency)}',
        ),
      );

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialExpense != null;
    final trip = ref.watch(currentTripProvider);
    final stoppages = ref.watch(currentTripStoppagesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (trip == null) {
      return const Scaffold(body: Center(child: Text('Trip not found')));
    }

    _initMemberSplits(trip.members);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Activity Bill' : 'Add Activity Bill / Expense'),
        actions: [
          TextButton(
            onPressed: _submit,
            child: Text(isEditing ? 'Update' : 'Save', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Stoppage Anchor Selector
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withAlpha(50)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.pin_drop_rounded, color: AppTheme.primary, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Anchor to Stoppage:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: _selectedStoppageId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      fillColor: Colors.white,
                      filled: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('General Trip Expense (No stop)', overflow: TextOverflow.ellipsis),
                      ),
                      ...stoppages.map((s) {
                        return DropdownMenuItem<String?>(
                          value: s.id,
                          child: Text('📍 ${s.name} (${s.category})', overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (val) => setState(() => _selectedStoppageId = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Title & Amount
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Expense Title *',
                hintText: 'e.g. Seafood Dinner, Fuel at Station, Toll Pass',
                prefixIcon: Icon(Icons.shopping_bag_outlined),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a description' : null,
            ),
            const SizedBox(height: 14),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Total Amount *',
                      prefixText: '${CurrencyFormatter.getCurrencySymbol(trip.defaultCurrency)} ',
                      prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter amount' : null,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    items: AppConstants.expenseCategories.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(
                          c,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Payer & Split Section
            if (trip.isSolo) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(20),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.withAlpha(60)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.backpack_rounded, color: Colors.blue, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '🎒 Solo Journey: 100% of this expense is tracked directly for your personal budget.',
                        style: TextStyle(fontSize: 12, color: Colors.blue, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              if (trip.isFamily) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.family_restroom_rounded, color: Colors.orange, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '👨‍👩‍👧 Family Pool: Recorded for family budget tracking.',
                          style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Text('Paid By:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: trip.members.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final member = trip.members[index];
                    final isSelected = _paidByMemberId == member.id;
                    final memberColor = member.colorHex != null
                        ? Color(int.parse(member.colorHex!))
                        : AppTheme.primary;

                    return ChoiceChip(
                      showCheckmark: false,
                      selected: isSelected,
                      label: Text(member.name),
                      avatar: CircleAvatar(
                        backgroundColor: memberColor,
                        child: Text(
                          member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      selectedColor: AppTheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _paidByMemberId = member.id);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Split Mode Selector
              const Text('Split Method:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              SegmentedButton<SplitType>(
                segments: [
                  const ButtonSegment(value: SplitType.equal, label: Text('Equally')),
                  ButtonSegment(
                    value: SplitType.exact,
                    label: Text('Exact ${CurrencyFormatter.getCurrencySymbol(trip.defaultCurrency)}'),
                  ),
                  const ButtonSegment(value: SplitType.percentage, label: Text('Percent %')),
                ],
                selected: {_splitType},
                onSelectionChanged: (val) {
                  setState(() => _splitType = val.first);
                },
              ),
              const SizedBox(height: 16),
            ],

            // Split Breakdown Card (Group & Family only)
            if (!trip.isSolo) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withAlpha(50)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Member Cost Shares', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 12),
                    ...trip.members.map((m) {
                      final isIncluded = _equalIncluded[m.id] ?? true;
                      final total = double.tryParse(_amountController.text) ?? 0.0;

                      if (_splitType == SplitType.equal) {
                        final incCount = _equalIncluded.values.where((v) => v).length;
                        final perPerson = incCount > 0 ? (total / incCount) : 0.0;
                        return CheckboxListTile(
                          value: isIncluded,
                          title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            isIncluded
                                ? CurrencyFormatter.format(perPerson, currency: trip.defaultCurrency)
                                : 'Excluded from bill',
                            style: TextStyle(
                              color: isIncluded ? AppTheme.primary : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          activeColor: AppTheme.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) {
                            setState(() => _equalIncluded[m.id] = val ?? false);
                          },
                        );
                      } else if (_splitType == SplitType.exact) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                              SizedBox(
                                width: 110,
                                child: TextField(
                                  controller: _exactControllers[m.id],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    prefixText: '${CurrencyFormatter.getCurrencySymbol(trip.defaultCurrency)} ',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        // Percentage
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                              SizedBox(
                                width: 90,
                                child: TextField(
                                  controller: _percentControllers[m.id],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    suffixText: '%',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Optional Bill / Receipt Upload Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _receiptImagePath != null ? Colors.green.withAlpha(120) : Colors.grey.withAlpha(50),
                  width: _receiptImagePath != null ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 18,
                            color: _receiptImagePath != null ? Colors.green : AppTheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Attach Bill / Receipt',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _receiptImagePath != null
                              ? Colors.green.withAlpha(30)
                              : Colors.grey.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _receiptImagePath != null ? '✓ Attached' : 'Optional',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _receiptImagePath != null ? Colors.green : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_receiptImagePath != null) ...[
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 70,
                            height: 70,
                            child: _buildReceiptThumbnail(_receiptImagePath!),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bill image ready',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Will be shared with companions',
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _pickReceiptImage(ImageSource.gallery),
                                    icon: const Icon(Icons.refresh_rounded, size: 14),
                                    label: const Text('Change', style: TextStyle(fontSize: 11)),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () => setState(() => _receiptImagePath = null),
                                    icon: const Icon(Icons.close_rounded, size: 14, color: Colors.red),
                                    label: const Text('Remove', style: TextStyle(fontSize: 11, color: Colors.red)),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickReceiptImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_rounded, size: 16),
                            label: const Text('Camera', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickReceiptImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded, size: 16),
                            label: const Text('Gallery', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Or pick sample bill:',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 48,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _sampleReceipts.length,
                        itemBuilder: (context, index) {
                          final sample = _sampleReceipts[index];
                          return GestureDetector(
                            onTap: () => setState(() => _receiptImagePath = sample),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.primary.withAlpha(80)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Image.network(sample, fit: BoxFit.cover),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes / Invoice Details (Optional)',
                hintText: 'Additional details or invoice note',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text(
                isEditing ? 'Save Changes & Log' : 'Add Expense to Trip',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
