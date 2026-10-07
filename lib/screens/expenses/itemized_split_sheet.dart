import 'package:flutter/material.dart';
import '../../models/itemized_split_breakdown.dart';
import '../../core/services/itemized_split_engine.dart';

class ItemizedSplitSheet extends StatefulWidget {
  final double totalAmount;
  final List<String> memberNames;
  final String currency;
  final ValueChanged<ItemizedSplitBreakdown>? onConfirmBreakdown;

  const ItemizedSplitSheet({
    super.key,
    required this.totalAmount,
    required this.memberNames,
    this.currency = 'INR',
    this.onConfirmBreakdown,
  });

  @override
  State<ItemizedSplitSheet> createState() => _ItemizedSplitSheetState();
}

class _ItemizedSplitSheetState extends State<ItemizedSplitSheet> {
  String _selectedMethod = 'equal';
  late ItemizedSplitBreakdown _breakdown;
  final ItemizedSplitEngine _engine = ItemizedSplitEngine();

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  void _recalculate() {
    if (_selectedMethod == 'equal') {
      _breakdown = _engine.splitEqual(
        totalAmount: widget.totalAmount,
        memberNames: widget.memberNames,
        currency: widget.currency,
      );
    } else if (_selectedMethod == 'shares') {
      // Default: 1 share each, first gets 2
      final shares = {for (var m in widget.memberNames) m: 1.0};
      if (widget.memberNames.isNotEmpty) {
        shares[widget.memberNames.first] = 2.0;
      }
      _breakdown = _engine.splitByShares(
        totalAmount: widget.totalAmount,
        memberShares: shares,
        currency: widget.currency,
      );
    } else {
      // Percentage
      final pct = 100.0 / (widget.memberNames.isNotEmpty ? widget.memberNames.length : 1);
      final pcts = {for (var m in widget.memberNames) m: pct};
      _breakdown = _engine.splitByPercentages(
        totalAmount: widget.totalAmount,
        memberPercentages: pcts,
        currency: widget.currency,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.call_split_rounded, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expense Split Engine',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Total: ${widget.currency} ${widget.totalAmount.toStringAsFixed(2)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Method Selector (AQIL Wrap)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Equal Split'),
                selected: _selectedMethod == 'equal',
                onSelected: (sel) {
                  if (sel) {
                    setState(() {
                      _selectedMethod = 'equal';
                      _recalculate();
                    });
                  }
                },
              ),
              ChoiceChip(
                label: const Text('Weighted Shares'),
                selected: _selectedMethod == 'shares',
                onSelected: (sel) {
                  if (sel) {
                    setState(() {
                      _selectedMethod = 'shares';
                      _recalculate();
                    });
                  }
                },
              ),
              ChoiceChip(
                label: const Text('Percentages'),
                selected: _selectedMethod == 'percentage',
                onSelected: (sel) {
                  if (sel) {
                    setState(() {
                      _selectedMethod = 'percentage';
                      _recalculate();
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Member list
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: _breakdown.memberOwedAmounts.entries.map((entry) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.currency} ${entry.value.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Confirm button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                widget.onConfirmBreakdown?.call(_breakdown);
                Navigator.of(context, rootNavigator: true).maybePop();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Confirm Split Breakdown'),
            ),
          ),
        ],
      ),
    );
  }
}
