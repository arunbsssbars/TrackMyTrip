import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/ocr_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/trip.dart';
import '../../providers/expense_provider.dart';
import '../../providers/trip_provider.dart';
import '../expense/add_expense_screen.dart';

import '../../core/services/security_service.dart';

class ExpensesTab extends ConsumerStatefulWidget {
  const ExpensesTab({super.key});

  @override
  ConsumerState<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends ConsumerState<ExpensesTab> {
  bool _isProcessingOcr = false;

  @override
  void initState() {
    super.initState();
    // MASVS-RESILIENCE: Protect sensitive billing/expense data from screen capture
    SecurityService.setSecureScreen(true);
  }

  @override
  void dispose() {
    SecurityService.setSecureScreen(false);
    super.dispose();
  }

  void _scanReceipt(BuildContext context, List<Trip> trips) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    if (trips.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Create a trip first to add expenses!')),
      );
      return;
    }

    Trip? selectedTrip;
    if (trips.length == 1) {
      selectedTrip = trips.first;
    } else {
      // Pick a trip
      selectedTrip = await showModalBottomSheet<Trip>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _TripSelectionSheet(trips: trips),
      );
    }

    if (selectedTrip == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    
    if (image == null) return; // User cancelled camera

    if (mounted) {
      setState(() {
        _isProcessingOcr = true;
      });
    }

    try {
      final ocrResult = await OcrService.extractFromReceipt(image.path);
      
      if (mounted) {
        setState(() {
          _isProcessingOcr = false;
        });
        
        // Set current trip provider context so AddExpenseScreen knows which trip
        ref.read(selectedTripIdProvider.notifier).state = selectedTrip.id;
        
        nav.push(
          MaterialPageRoute(
            builder: (ctx) => AddExpenseScreen(
              tripId: selectedTrip!.id,
              prefillTitle: ocrResult.title,
              prefillAmount: ocrResult.amount,
              prefillImagePath: image.path,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingOcr = false;
        });
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to process receipt: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allExpenses = ref.watch(allExpensesProvider);
    final trips = ref.watch(tripListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Strictly filter to expenses belonging to the active user's trips
    final validTripIds = trips.map((t) => t.id).toSet();
    final validExpenses = allExpenses.where((e) => validTripIds.contains(e.tripId)).toList();

    // Sort expenses by date descending
    final sortedExpenses = List.of(validExpenses)..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Expenses'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          sortedExpenses.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No expenses recorded yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16).copyWith(bottom: 100),
                  itemCount: sortedExpenses.length,
                  itemBuilder: (context, index) {
                    final exp = sortedExpenses[index];
                    final trip = trips.where((t) => t.id == exp.tripId).firstOrNull;
                    final tripName = trip?.title ?? 'Unknown Trip';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.receipt, color: AppTheme.primary),
                        ),
                        title: Text(exp.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('$tripName • ${DateFormatter.formatShortDate(exp.createdAt)}'),
                        trailing: Text(
                          CurrencyFormatter.format(exp.totalAmount, currency: exp.currency),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.primary),
                        ),
                      ),
                    );
                  },
                ),
          
          if (_isProcessingOcr)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Scanning Receipt...', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('Extracting amounts and dates', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D9488).withAlpha(90),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: Colors.white.withAlpha(50), width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isProcessingOcr ? null : () => _scanReceipt(context, trips),
            borderRadius: BorderRadius.circular(24),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 13, vertical: 8.5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.document_scanner_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 5.5),
                  Text(
                    'Scan Receipt',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TripSelectionSheet extends StatelessWidget {
  final List<Trip> trips;
  const _TripSelectionSheet({required this.trips});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Select Trip for Receipt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: trips.length,
              itemBuilder: (context, index) {
                final trip = trips[index];
                return ListTile(
                  leading: const Icon(Icons.explore_rounded, color: AppTheme.primary),
                  title: Text(trip.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${trip.members.length} members'),
                  onTap: () => Navigator.of(context).pop(trip),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
