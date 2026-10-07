import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/debt_simplifier.dart';
import '../../../models/settlement.dart';
import '../../../models/trip.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/settlement_provider.dart';
import '../../../providers/trip_provider.dart';
import '../../common/user_avatar.dart';

class SettlementTab extends ConsumerStatefulWidget {
  final Trip trip;

  const SettlementTab({super.key, required this.trip});

  static String generateSettlementSummaryReport(Trip trip, Map<String, double> netBalances, List<DebtTransfer> transfers) {
    final buffer = StringBuffer();
    buffer.writeln('💰 Settlement Summary: ${trip.title}');
    buffer.writeln('----------------------------------------');
    if (transfers.isEmpty) {
      buffer.writeln('✨ All companions are completely settled up!');
    } else {
      buffer.writeln('Recommended Transfers to Settle:');
      for (final t in transfers) {
        final fromName = trip.getMemberName(t.fromMemberId);
        final toName = trip.getMemberName(t.toMemberId);
        final amt = CurrencyFormatter.format(t.amount, currency: trip.defaultCurrency);
        buffer.writeln('• $fromName pays $toName: $amt');
      }
    }
    buffer.writeln('\nIndividual Balances:');
    for (final m in trip.members) {
      final bal = netBalances[m.id] ?? 0.0;
      final formatted = CurrencyFormatter.format(bal.abs(), currency: trip.defaultCurrency);
      if (bal > 0.01) {
        buffer.writeln('• ${m.name}: +$formatted (gets back)');
      } else if (bal < -0.01) {
        buffer.writeln('• ${m.name}: -$formatted (owes)');
      } else {
        buffer.writeln('• ${m.name}: Settled');
      }
    }
    buffer.writeln('----------------------------------------');
    buffer.writeln('Tracked with TrackMyTrip');
    return buffer.toString();
  }

  static String generateSettlementCsv(
    Trip trip,
    Map<String, double> netBalances,
    List<DebtTransfer> transfers,
    List<Settlement> settlements,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('Type,Member Name,Member ID,Amount,Currency,Status');
    for (final m in trip.members) {
      final bal = netBalances[m.id] ?? 0.0;
      final status = bal > 0.01 ? 'Gets Back' : (bal < -0.01 ? 'Owes' : 'Settled');
      buffer.writeln('Balance,"${m.name.replaceAll('"', '""')}",${m.id},${bal.toStringAsFixed(2)},${trip.defaultCurrency},$status');
    }
    buffer.writeln('\nTransfer Type,From Member,To Member,Amount,Currency');
    for (final t in transfers) {
      final fromName = trip.getMemberName(t.fromMemberId);
      final toName = trip.getMemberName(t.toMemberId);
      buffer.writeln('Recommended Transfer,"${fromName.replaceAll('"', '""')}","${toName.replaceAll('"', '""')}",${t.amount.toStringAsFixed(2)},${trip.defaultCurrency}');
    }
    buffer.writeln('\nSettlement ID,Payer,Receiver,Amount,Currency,Payment Method,Date,Notes');
    for (final s in settlements) {
      final payerName = trip.getMemberName(s.payerMemberId);
      final receiverName = trip.getMemberName(s.receiverMemberId);
      final dateStr = s.settledAt.toIso8601String().split('T').first;
      final noteSafe = (s.notes ?? '').replaceAll('"', '""');
      buffer.writeln('${s.id},"${payerName.replaceAll('"', '""')}","${receiverName.replaceAll('"', '""')}",${s.amount.toStringAsFixed(2)},${trip.defaultCurrency},${s.paymentMethod},$dateStr,"$noteSafe"');
    }
    return buffer.toString();
  }

  @override
  ConsumerState<SettlementTab> createState() => _SettlementTabState();
}

class _SettlementTabState extends ConsumerState<SettlementTab> {
  void _openRecordSettlementDialog(BuildContext context, {DebtTransfer? defaultTransfer, Settlement? existingSettlement}) {
    final trips = ref.read(tripListProvider);
    final currentTrip = trips.where((t) => t.id == widget.trip.id).firstOrNull ?? widget.trip;

    if (currentTrip.members.length < 2) {
      AppSnackBar.showWarning(context, 'At least 2 members are required to record a payment.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecordPaymentSheet(
        trip: currentTrip,
        defaultTransfer: defaultTransfer,
        existingSettlement: existingSettlement,
      ),
    );
  }

  void _shareSettlementSummary(Trip trip, Map<String, double> netBalances, List<DebtTransfer> transfers) {
    final buffer = StringBuffer();
    buffer.writeln('💰 Settlement Summary: ${trip.title}');
    buffer.writeln('----------------------------------------');
    if (transfers.isEmpty) {
      buffer.writeln('✨ All companions are completely settled up!');
    } else {
      buffer.writeln('Recommended Transfers to Settle:');
      for (final t in transfers) {
        final fromName = trip.getMemberName(t.fromMemberId);
        final toName = trip.getMemberName(t.toMemberId);
        final amt = CurrencyFormatter.format(t.amount, currency: trip.defaultCurrency);
        buffer.writeln('• $fromName pays $toName: $amt');
      }
    }
    buffer.writeln('\nIndividual Balances:');
    for (final m in trip.members) {
      final bal = netBalances[m.id] ?? 0.0;
      final formatted = CurrencyFormatter.format(bal.abs(), currency: trip.defaultCurrency);
      if (bal > 0.01) {
        buffer.writeln('• ${m.name}: +$formatted (gets back)');
      } else if (bal < -0.01) {
        buffer.writeln('• ${m.name}: -$formatted (owes)');
      } else {
        buffer.writeln('• ${m.name}: Settled');
      }
    }
    buffer.writeln('----------------------------------------');
    buffer.writeln('Tracked with TrackMyTrip');
    Share.share(buffer.toString(), subject: 'Settlement Summary - ${trip.title}');
  }

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(tripListProvider);
    final currentTrip = trips.where((t) => t.id == widget.trip.id).firstOrNull ?? widget.trip;
    final authUser = ref.watch(authNotifierProvider).valueOrNull;
    final currentUid = authUser?.id;

    final netBalances = ref.watch(tripNetBalancesProvider);
    final simplifiedTransfers = ref.watch(simplifiedTransfersProvider);
    final settlements = ref.watch(currentTripSettlementsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final hPad = screenWidth < 360
        ? 10.0
        : (screenWidth >= 800 ? ((screenWidth - 760) / 2).clamp(16.0, 380.0) : 16.0);

    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 80),
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
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              currentTrip.isFamily ? 'Family Member Contributions' : 'Individual Balances',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : AppTheme.textMainLight,
              ),
            ),
            Consumer(builder: (context, ref, _) {
              final imbalance = ref.watch(ledgerImbalanceProvider);
              final isZeroDrift = imbalance.abs() < 0.01;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isZeroDrift ? const Color(0xFF10B981).withAlpha(20) : Colors.orange.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isZeroDrift ? const Color(0xFF10B981).withAlpha(60) : Colors.orange.withAlpha(80),
                    width: 0.9,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isZeroDrift ? Icons.verified_rounded : Icons.info_outline_rounded,
                      size: 12,
                      color: isZeroDrift ? const Color(0xFF10B981) : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isZeroDrift ? 'Ledger Balanced' : 'Drift: ${CurrencyFormatter.format(imbalance, currency: currentTrip.defaultCurrency)}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isZeroDrift ? const Color(0xFF10B981) : Colors.orange,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 8),
        ...currentTrip.members.map((member) {
          final isMe = (currentUid != null && member.id == currentUid) ||
              (authUser?.email != null && member.email != null && authUser!.email.toLowerCase() == member.email!.toLowerCase());

          final isMemberCreator = currentTrip.isMemberCreator(member);

          final balance = netBalances[member.id] ?? 0.0;
          final isPositive = balance > 0.01;
          final isNegative = balance < -0.01;
          final isSettled = !isPositive && !isNegative;

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isMemberCreator
                    ? (isDark ? const Color(0xFFF59E0B).withAlpha(100) : const Color(0xFFF59E0B).withAlpha(160))
                    : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
                width: isMemberCreator ? 1.4 : 1.1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  final matchingTransfer = simplifiedTransfers
                      .where((t) => t.fromMemberId == member.id || t.toMemberId == member.id)
                      .firstOrNull;
                  if (matchingTransfer != null) {
                    _openRecordSettlementDialog(context, defaultTransfer: matchingTransfer);
                  } else if (!isSettled) {
                    _openRecordSettlementDialog(context);
                  }
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth < 360 ? 8 : 12, vertical: 10),
                  child: Row(
                    children: [
                      UserAvatar(
                        name: member.name,
                        colorHex: member.colorHex,
                        size: 38,
                        border: isMemberCreator ? Border.all(color: const Color(0xFFF59E0B), width: 1.5) : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              member.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isMemberCreator || isMe) ...[
                              const SizedBox(height: 2),
                              Wrap(
                                spacing: 4,
                                runSpacing: 2,
                                children: [
                                  if (isMemberCreator)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF382E12) : const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFFF59E0B).withAlpha(120) : const Color(0xFFF59E0B),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.workspace_premium_rounded,
                                            size: 9.5,
                                            color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                                          ),
                                          const SizedBox(width: 2.5),
                                          Flexible(
                                            child: Text(
                                              'Creator',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (isMe)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppTheme.primary.withAlpha(50) : AppTheme.primary.withAlpha(25),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: AppTheme.primary.withAlpha(80), width: 0.8),
                                      ),
                                      child: const Text(
                                        'You',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              isSettled
                                  ? 'All settled up'
                                  : (isPositive ? 'Is owed money by group' : 'Owes money to group'),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: isSettled ? Colors.grey : (isPositive ? Colors.green : Colors.orange),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSettled
                              ? Colors.grey.withAlpha(20)
                              : (isPositive ? Colors.green.withAlpha(20) : Colors.red.withAlpha(20)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isSettled
                              ? CurrencyFormatter.format(0.0, currency: currentTrip.defaultCurrency)
                              : (isPositive
                                  ? '+${CurrencyFormatter.format(balance, currency: currentTrip.defaultCurrency)}'
                                  : '-${CurrencyFormatter.format(balance.abs(), currency: currentTrip.defaultCurrency)}'),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: isSettled ? Colors.grey : (isPositive ? Colors.green : Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 20),

        // Simplified Debt Transfers (The Solution)
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(
              'Simplified Transfers',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : AppTheme.textMainLight,
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.share_rounded, size: 13),
                  label: const Text('Share', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => _shareSettlementSummary(currentTrip, netBalances, simplifiedTransfers),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.payment_rounded, size: 14),
                  label: const Text('Record', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => _openRecordSettlementDialog(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
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
            final fromMember = currentTrip.getMember(transfer.fromMemberId);
            final toMember = currentTrip.getMember(transfer.toMemberId);

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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 270;
                        final detailsCol = Column(
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
                              CurrencyFormatter.format(transfer.amount, currency: currentTrip.defaultCurrency),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ],
                        );

                        final markPaidBtn = FilledButton(
                          onPressed: () => _openRecordSettlementDialog(context, defaultTransfer: transfer),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Mark Paid', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
                              SizedBox(width: 2),
                              Icon(Icons.chevron_right_rounded, size: 13, color: Colors.white),
                            ],
                          ),
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.arrow_circle_right_rounded, color: Color(0xFFD97706), size: 26),
                                  const SizedBox(width: 8),
                                  Expanded(child: detailsCol),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(alignment: Alignment.centerRight, child: markPaidBtn),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            const Icon(Icons.arrow_circle_right_rounded, color: Color(0xFFD97706), size: 28),
                            const SizedBox(width: 10),
                            Expanded(child: detailsCol),
                            const SizedBox(width: 6),
                            markPaidBtn,
                          ],
                        );
                      },
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
              Expanded(
                child: Text(
                  'Payment History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark ? Colors.white : AppTheme.textMainLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
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

class _RecordPaymentSheet extends ConsumerStatefulWidget {
  final Trip trip;
  final DebtTransfer? defaultTransfer;
  final Settlement? existingSettlement;

  const _RecordPaymentSheet({
    required this.trip,
    this.defaultTransfer,
    this.existingSettlement,
  });

  @override
  ConsumerState<_RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<_RecordPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _payerId;
  late String _receiverId;
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  late String _paymentMethod;
  bool _isAdvance = false;

  final List<(String, IconData)> _paymentMethods = const [
    ('Cash / Direct', Icons.payments_rounded),
    ('UPI / Google Pay', Icons.qr_code_rounded),
    ('Venmo / PayPal', Icons.send_rounded),
    ('Bank Transfer', Icons.account_balance_rounded),
    ('Other', Icons.more_horiz_rounded),
  ];

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
      final otherMembers = widget.trip.members.where((m) => m.id != _payerId).toList();
      _receiverId = transfer?.toMemberId ?? (otherMembers.isNotEmpty ? otherMembers.first.id : '');
      _amountController = TextEditingController(text: transfer != null ? transfer.amount.toStringAsFixed(2) : '');
      _notesController = TextEditingController();
      _paymentMethod = 'Cash / Direct';
      _isAdvance = false;
    }

    // Safety guard: ensure payer and receiver are never identical on startup
    if (_payerId == _receiverId && widget.trip.members.length > 1) {
      final fallback = widget.trip.members.firstWhere((m) => m.id != _payerId);
      _receiverId = fallback.id;
    }
  }

  void _swapMembers() {
    HapticFeedback.lightImpact();
    setState(() {
      final temp = _payerId;
      _payerId = _receiverId;
      _receiverId = temp;
    });
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
      AppSnackBar.showError(context, 'Payer and receiver cannot be the same person');
      return;
    }

    final amount = double.parse(_amountController.text.trim());

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
    }

    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  void _deleteSettlement() async {
    if (widget.existingSettlement == null) return;

    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Delete Payment Record?',
      message: 'This will remove the settlement and recalculate balances.',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: Icons.delete_forever_rounded,
    );

    if (confirmed && mounted) {
      ref.read(allSettlementsProvider.notifier).deleteSettlement(widget.existingSettlement!.id);
      Navigator.of(context).pop();
      AppSnackBar.showSuccess(context, 'Payment record deleted.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingSettlement != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 80 : 30),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 10,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    width: 38,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withAlpha(22),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.handshake_rounded, size: 20, color: AppTheme.primary),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? 'Edit Payment' : 'Record Payment',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.3),
                            ),
                            Text(
                              'Direct member-to-member debt settlement',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isEditing)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                            tooltip: 'Delete Payment',
                            onPressed: _deleteSettlement,
                          ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 22, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Directional Transfer Visualizer (Payer -> Receiver)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Payer Card
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.arrow_upward_rounded, size: 12, color: AppTheme.primary),
                                const SizedBox(width: 3),
                                Text(
                                  'PAID BY',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.surfaceDark : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1),
                                  width: 0.9,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _payerId.isNotEmpty ? _payerId : null,
                                  isExpanded: true,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                                  items: widget.trip.members.map((m) {
                                    final isOpposite = m.id == _receiverId;
                                    return DropdownMenuItem(
                                      value: m.id,
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 11,
                                            backgroundColor: AppTheme.primary.withAlpha(30),
                                            child: Text(
                                              m.initials,
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              m.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                          if (isOpposite)
                                            Container(
                                              margin: const EdgeInsets.only(left: 4),
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: AppTheme.secondary.withAlpha(25),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('Swap', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
                                            ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        if (val == _receiverId) {
                                          _receiverId = _payerId;
                                        }
                                        _payerId = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Directional Transfer Indicator with Tap-to-Swap
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          children: [
                            const SizedBox(height: 14),
                            Tooltip(
                              message: 'Swap Payer & Receiver',
                              child: Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  onTap: _swapMembers,
                                  customBorder: const CircleBorder(),
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withAlpha(20),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppTheme.primary.withAlpha(60), width: 0.9),
                                    ),
                                    child: const Icon(Icons.swap_horiz_rounded, size: 16, color: AppTheme.primary),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Receiver Card
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.arrow_downward_rounded, size: 12, color: AppTheme.secondary),
                                const SizedBox(width: 3),
                                Text(
                                  'RECEIVED BY',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.surfaceDark : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1),
                                  width: 0.9,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _receiverId.isNotEmpty ? _receiverId : null,
                                  isExpanded: true,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                                  items: widget.trip.members.map((m) {
                                    final isOpposite = m.id == _payerId;
                                    return DropdownMenuItem(
                                      value: m.id,
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 11,
                                            backgroundColor: AppTheme.secondary.withAlpha(30),
                                            child: Text(
                                              m.initials,
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.secondary),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              m.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                          if (isOpposite)
                                            Container(
                                              margin: const EdgeInsets.only(left: 4),
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primary.withAlpha(25),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('Swap', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                            ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        if (val == _payerId) {
                                          _payerId = _receiverId;
                                        }
                                        _receiverId = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_payerId == _receiverId) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withAlpha(60), width: 0.8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                        SizedBox(width: 6),
                        Text('Payer and receiver cannot be the same member.', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Hero Amount Input Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1),
                      width: 1.1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'AMOUNT TRANSFERRED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                            ),
                          ),
                          if (widget.defaultTransfer != null)
                            InkWell(
                              onTap: () {
                                _amountController.text = widget.defaultTransfer!.amount.toStringAsFixed(2);
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withAlpha(isDark ? 30 : 18),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.primary.withAlpha(50), width: 0.8),
                                ),
                                child: Text(
                                  'Settle Full (${CurrencyFormatter.format(widget.defaultTransfer!.amount, currency: widget.trip.defaultCurrency)})',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            CurrencyFormatter.getCurrencySymbol(widget.trip.defaultCurrency),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: isDark ? Colors.white : AppTheme.textMainLight,
                              ),
                              decoration: InputDecoration(
                                hintText: '0.00',
                                hintStyle: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Please enter amount';
                                final parsed = double.tryParse(val.trim());
                                if (parsed == null || parsed <= 0) return 'Enter valid amount';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Payment Method Selector Pills
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PAYMENT METHOD',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: _paymentMethods.map((entry) {
                        final methodName = entry.$1;
                        final methodIcon = entry.$2;
                        final isSelected = _paymentMethod == methodName;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => setState(() => _paymentMethod = methodName),
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primary.withAlpha(isDark ? 35 : 20)
                                    : (isDark ? Colors.white.withAlpha(8) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primary
                                      : (isDark ? Colors.white.withAlpha(16) : const Color(0xFFE2E8F0)),
                                  width: isSelected ? 1.2 : 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    methodIcon,
                                    size: 14,
                                    color: isSelected ? AppTheme.primary : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    methodName,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected
                                          ? AppTheme.primary
                                          : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Notes Field
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'e.g. Settle dinner, tolls, and fuel',
                    prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                    filled: true,
                    fillColor: isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.primary, width: 1.4),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),

                // Initial Advance Contribution Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withAlpha(6) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white.withAlpha(14) : const Color(0xFFE2E8F0),
                      width: 0.9,
                    ),
                  ),
                  child: SwitchListTile(
                    title: const Text(
                      'Advance Contribution',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Mark as an upfront deposit to the trip organizer',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: _isAdvance,
                    activeThumbColor: AppTheme.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() => _isAdvance = val);
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Submit Button
                FilledButton.icon(
                  onPressed: (_payerId.isNotEmpty && _receiverId.isNotEmpty && _payerId != _receiverId)
                      ? _saveSettlement
                      : null,
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(
                    isEditing ? 'Save Changes' : 'Record Payment',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDark ? Colors.white12 : Colors.grey[300],
                    disabledForegroundColor: isDark ? Colors.white30 : Colors.grey[500],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
