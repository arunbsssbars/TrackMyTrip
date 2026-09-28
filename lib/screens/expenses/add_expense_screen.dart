import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/location_service.dart';
import '../../core/services/ocr_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/expense.dart';
import '../../models/expense_split.dart';
import '../../models/trip.dart';
import '../../models/trip_member.dart';
import '../../models/trip_audit_log.dart';
import '../../providers/audit_log_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';
import '../stoppage/map_location_picker_dialog.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String? initialStoppageId;
  final Expense? initialExpense;
  final String? prefillTitle;
  final double? prefillAmount;
  final String? prefillImagePath;
  final String? prefillCategory;
  final String? prefillDescription;

  const AddExpenseScreen({
    super.key,
    required this.tripId,
    this.initialStoppageId,
    this.initialExpense,
    this.prefillTitle,
    this.prefillAmount,
    this.prefillImagePath,
    this.prefillCategory,
    this.prefillDescription,
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
  bool _isSplitExpanded = false; // Folded by default
  String? _receiptImagePath;
  bool _isScanningOcr = false;

  // Location tagging state
  bool _attachLocation = false;
  String? _locationName;
  double? _latitude;
  double? _longitude;
  bool _isDetectingLocation = false;

  // Split state per member
  final Map<String, bool> _equalIncluded = {};
  final Map<String, TextEditingController> _exactControllers = {};
  final Map<String, TextEditingController> _percentControllers = {};
  final Map<String, TextEditingController> _sharesControllers = {};

  // Multi-currency / Foreign conversion state (Issue 8)
  bool _useForeignCurrency = false;
  String _foreignCurrency = 'USD';
  final _foreignAmountController = TextEditingController();
  final _exchangeRateController = TextEditingController();

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

      // Restore tagged location if saved in notes
      if (exp.notes != null) {
        final match = RegExp(r'📍 Location:\s*([^\n]+)').firstMatch(exp.notes!);
        if (match != null) {
          _attachLocation = true;
          _locationName = match.group(1)?.trim();
          // Remove the location line from the raw notes text field so user doesn't see raw markup
          final cleanedNotes = exp.notes!.replaceAll(RegExp(r'📍 Location:[^\n]*\n?'), '').trim();
          _notesController.text = cleanedNotes;
        }
      }

      for (final s in exp.splits) {
        _equalIncluded[s.memberId] = s.isIncluded;
        _exactControllers[s.memberId] = TextEditingController(text: s.allocatedAmount.toStringAsFixed(2));
        _percentControllers[s.memberId] = TextEditingController(text: (s.percentage ?? 0).toStringAsFixed(1));
        _sharesControllers[s.memberId] = TextEditingController(text: (s.shares ?? 1.0).toStringAsFixed(0));
      }

      // Restore foreign conversion state if present
      if (exp.hasForeignConversion) {
        _useForeignCurrency = true;
        _foreignCurrency = exp.originalCurrency ?? 'USD';
        _foreignAmountController.text = exp.originalAmount != null ? exp.originalAmount!.toStringAsFixed(2) : '';
        _exchangeRateController.text = exp.exchangeRate != null ? exp.exchangeRate!.toStringAsFixed(4) : '';
      }
    } else {
      _selectedStoppageId = widget.initialStoppageId;
      if (widget.prefillTitle != null) {
        _titleController.text = widget.prefillTitle!;
      }
      if (widget.prefillAmount != null) {
        _amountController.text = widget.prefillAmount!.toStringAsFixed(2);
      }
      if (widget.prefillImagePath != null) {
        _receiptImagePath = widget.prefillImagePath;
      }
      if (widget.prefillCategory != null && AppConstants.expenseCategories.contains(widget.prefillCategory)) {
        _selectedCategory = widget.prefillCategory!;
      }
      if (widget.prefillDescription != null && widget.prefillDescription!.isNotEmpty) {
        _notesController.text = widget.prefillDescription!;
      }
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
    for (final c in _sharesControllers.values) {
      c.dispose();
    }
    _foreignAmountController.dispose();
    _exchangeRateController.dispose();
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
      _sharesControllers.putIfAbsent(member.id, () => TextEditingController(text: '1'));
    }
  }

  List<ExpenseSplit> _buildSplits(double totalAmount, List<TripMember> members) {
    final List<ExpenseSplit> splits = [];
    final totalCents = (totalAmount * 100).round();

    switch (_splitType) {
      case SplitType.equal:
        final includedMembers = members.where((m) => _equalIncluded[m.id] == true).toList();
        final includedCount = includedMembers.length;
        if (includedCount == 0) break;

        final baseCents = totalCents ~/ includedCount;
        final remainderCents = totalCents % includedCount;

        int distributedRemainder = 0;
        for (final member in members) {
          final isInc = _equalIncluded[member.id] ?? false;
          if (isInc) {
            final allocatedCents = baseCents + (distributedRemainder < remainderCents ? 1 : 0);
            distributedRemainder++;
            splits.add(
              ExpenseSplit(
                memberId: member.id,
                allocatedAmount: allocatedCents / 100.0,
                isIncluded: true,
              ),
            );
          } else {
            splits.add(
              ExpenseSplit(
                memberId: member.id,
                allocatedAmount: 0.0,
                isIncluded: false,
              ),
            );
          }
        }
        break;

      case SplitType.exact:
        for (final member in members) {
          final rawVal = double.tryParse(_exactControllers[member.id]?.text ?? '0') ?? 0.0;
          final roundedVal = (rawVal * 100).round() / 100.0;
          splits.add(
            ExpenseSplit(
              memberId: member.id,
              allocatedAmount: roundedVal,
              isIncluded: roundedVal > 0,
            ),
          );
        }
        break;

      case SplitType.percentage:
        int allocatedCentsTotal = 0;
        final memberCentsMap = <String, int>{};
        String? largestMemberId;
        double maxPct = -1;

        for (final member in members) {
          final pct = double.tryParse(_percentControllers[member.id]?.text ?? '0') ?? 0.0;
          if (pct > 0) {
            final cents = ((pct / 100.0) * totalCents).round();
            memberCentsMap[member.id] = cents;
            allocatedCentsTotal += cents;
            if (pct > maxPct) {
              maxPct = pct;
              largestMemberId = member.id;
            }
          } else {
            memberCentsMap[member.id] = 0;
          }
        }

        // Allocate single-cent drift caused by percentage rounding to largest stakeholder
        final diffCents = totalCents - allocatedCentsTotal;
        if (diffCents != 0 && largestMemberId != null) {
          memberCentsMap[largestMemberId] = (memberCentsMap[largestMemberId] ?? 0) + diffCents;
        }

        for (final member in members) {
          final pct = double.tryParse(_percentControllers[member.id]?.text ?? '0') ?? 0.0;
          final cents = memberCentsMap[member.id] ?? 0;
          splits.add(
            ExpenseSplit(
              memberId: member.id,
              allocatedAmount: cents / 100.0,
              percentage: pct,
              isIncluded: cents > 0,
            ),
          );
        }
        break;

      case SplitType.shares:
        double totalShares = 0.0;
        final sharesMap = <String, double>{};
        String? largestShareMemberId;
        double maxShare = -1;

        for (final member in members) {
          final s = double.tryParse(_sharesControllers[member.id]?.text ?? '0') ?? 0.0;
          final validShares = s > 0 ? s : 0.0;
          sharesMap[member.id] = validShares;
          totalShares += validShares;
          if (validShares > maxShare) {
            maxShare = validShares;
            largestShareMemberId = member.id;
          }
        }

        int allocatedCentsTotal = 0;
        final memberCentsMap = <String, int>{};

        if (totalShares > 0) {
          for (final member in members) {
            final sh = sharesMap[member.id] ?? 0.0;
            if (sh > 0) {
              final cents = ((sh / totalShares) * totalCents).round();
              memberCentsMap[member.id] = cents;
              allocatedCentsTotal += cents;
            } else {
              memberCentsMap[member.id] = 0;
            }
          }
          final diffCents = totalCents - allocatedCentsTotal;
          if (diffCents != 0 && largestShareMemberId != null) {
            memberCentsMap[largestShareMemberId] = (memberCentsMap[largestShareMemberId] ?? 0) + diffCents;
          }
        }

        for (final member in members) {
          final sh = sharesMap[member.id] ?? 0.0;
          final cents = memberCentsMap[member.id] ?? 0;
          splits.add(
            ExpenseSplit(
              memberId: member.id,
              allocatedAmount: cents / 100.0,
              shares: sh,
              isIncluded: cents > 0,
            ),
          );
        }
        break;
    }

    return splits;
  }

  Future<void> _scanReceiptWithOcr([ImageSource source = ImageSource.camera]) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isScanningOcr = true);

      String savedPath;
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        savedPath = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      } else {
        savedPath = picked.path;
      }

      // Run on-device Google ML Kit OCR
      OcrResult? ocrResult;
      if (!kIsWeb) {
        ocrResult = await OcrService.extractFromReceipt(picked.path);
      }

      if (mounted) {
        setState(() {
          _receiptImagePath = savedPath;
          if (ocrResult != null) {
            if (ocrResult.title.isNotEmpty && ocrResult.title != 'Unknown Receipt') {
              _titleController.text = ocrResult.title;
            }
            if (ocrResult.amount > 0) {
              _amountController.text = ocrResult.amount.toStringAsFixed(2);
            }
            if (AppConstants.expenseCategories.contains(ocrResult.category)) {
              _selectedCategory = ocrResult.category;
            }
            if (ocrResult.description.isNotEmpty && _notesController.text.isEmpty) {
              _notesController.text = ocrResult.description;
            }
          }
          _isScanningOcr = false;
        });

        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ocrResult != null && ocrResult.amount > 0
                        ? 'Scanned: ${ocrResult.title} • ${CurrencyFormatter.format(ocrResult.amount)}'
                        : 'Receipt attached. You can review or edit amount.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanningOcr = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR scanning error: $e')),
        );
      }
    }
  }

  void _showOcrSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.document_scanner_rounded, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart Receipt OCR',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Auto-fill title, amount & attach image',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.blue),
                ),
                title: const Text('Capture with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Snap a picture of your paper bill or receipt', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _scanReceiptWithOcr(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Colors.purple),
                ),
                title: const Text('Select from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Choose a receipt screenshot or photo', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _scanReceiptWithOcr(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildReceiptImage(String path) {
    if (path.startsWith('data:image')) {
      final base64Data = path.split(',').last;
      return Image.memory(base64Decode(base64Data), fit: BoxFit.contain);
    } else if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(path, fit: BoxFit.contain);
    } else if (!kIsWeb) {
      return Image.file(File(path), fit: BoxFit.contain);
    } else {
      return const Center(child: Icon(Icons.receipt_long_rounded, size: 48, color: AppTheme.primary));
    }
  }

  void _showReceiptFullscreen(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: _buildReceiptImage(path),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(120),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(160),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Pinch to zoom • Tap ✕ to close',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _autoMatchStoppage(double lat, double lng) {
    try {
      final stoppages = ref.read(currentTripStoppagesProvider);
      String? closestId;
      double minDistance = double.infinity;
      for (final s in stoppages) {
        
          final dist = Geolocator.distanceBetween(lat, lng, s.latitude, s.longitude);
          if (dist <= 1500 && dist < minDistance) {
            minDistance = dist;
            closestId = s.id;
          }
      }
      if (closestId != null) {
        _selectedStoppageId = closestId;
      }
    } catch (_) {}
  }

  Future<void> _detectCurrentLocation() async {
    setState(() => _isDetectingLocation = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null) {
        final details = await LocationService.reverseGeocode(pos.latitude, pos.longitude);
        if (mounted) {
          _autoMatchStoppage(pos.latitude, pos.longitude);
          setState(() {
            _latitude = pos.latitude;
            _longitude = pos.longitude;
            final resolved = details.placeName.trim().isNotEmpty ? details.placeName : details.address;
            _locationName = (resolved != null && resolved.trim().isNotEmpty)
                ? resolved.trim()
                : 'GPS: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
            _isDetectingLocation = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isDetectingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not obtain current GPS position.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDetectingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location error: $e')),
        );
      }
    }
  }

  Future<void> _pickLocationOnMap() async {
    final result = await MapLocationPickerDialog.show(
      context,
      initialPosition: _latitude != null && _longitude != null ? LatLng(_latitude!, _longitude!) : null,
    );
    if (result != null && mounted) {
      _autoMatchStoppage(result.latitude, result.longitude);
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _locationName = result.placeName.isNotEmpty ? result.placeName : (result.address ?? 'Pinned Map Location');
      });
    }
  }

  void _recalculateFromForeign() {
    final foreignAmt = double.tryParse(_foreignAmountController.text.trim()) ?? 0.0;
    final rate = double.tryParse(_exchangeRateController.text.trim()) ?? 0.0;
    if (foreignAmt > 0 && rate > 0) {
      final converted = foreignAmt * rate;
      _amountController.text = converted.toStringAsFixed(2);
      setState(() {});
    }
  }

  Widget _buildCurrencyConversionCard(Trip trip) {
    final baseCurrency = trip.defaultCurrency;
    final baseSymbol = CurrencyFormatter.getCurrencySymbol(baseCurrency);
    final foreignSymbol = CurrencyFormatter.getCurrencySymbol(_foreignCurrency);

    return Container(
      decoration: BoxDecoration(
        color: _useForeignCurrency ? Colors.blue.withAlpha(15) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _useForeignCurrency ? Colors.blue.withAlpha(80) : Colors.grey.withAlpha(40),
        ),
      ),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            value: _useForeignCurrency,
            title: Row(
              children: [
                const Icon(Icons.currency_exchange_rounded, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Paid in Foreign Currency?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _useForeignCurrency ? Colors.blue : null,
                  ),
                ),
              ],
            ),
            subtitle: Text(
              _useForeignCurrency
                  ? 'Auto-convert to trip currency ($baseCurrency $baseSymbol)'
                  : 'Enable if spending in another country\'s currency',
              style: const TextStyle(fontSize: 12),
            ),
            onChanged: (val) {
              setState(() {
                _useForeignCurrency = val;
                if (!_useForeignCurrency) {
                  _foreignAmountController.clear();
                  _exchangeRateController.clear();
                } else if (_foreignCurrency.toUpperCase() == baseCurrency.toUpperCase()) {
                  _foreignCurrency = baseCurrency.toUpperCase() == 'USD' ? 'EUR' : 'USD';
                }
              });
            },
          ),
          if (_useForeignCurrency) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Foreign currency selector
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<String>(
                          initialValue: CurrencyFormatter.commonCurrencies.contains(_foreignCurrency)
                              ? _foreignCurrency
                              : 'USD',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Spent In',
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          items: CurrencyFormatter.commonCurrencies
                              .where((c) => c.toUpperCase() != baseCurrency.toUpperCase())
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      '$c (${CurrencyFormatter.getCurrencySymbol(c)})',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (c) {
                            if (c != null) {
                              setState(() => _foreignCurrency = c);
                              _recalculateFromForeign();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Foreign amount
                      Expanded(
                        flex: 6,
                        child: TextFormField(
                          controller: _foreignAmountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Foreign Amount',
                            hintText: '0.00',
                            prefixText: '$foreignSymbol ',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          onChanged: (_) => _recalculateFromForeign(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Exchange rate input
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _exchangeRateController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Exchange Rate',
                            hintText: 'e.g. 90.50',
                            helperText: '1 $_foreignCurrency = [Rate] $baseCurrency',
                            prefixIcon: const Icon(Icons.swap_horiz_rounded, size: 18),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          onChanged: (_) => _recalculateFromForeign(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Calculated in Trip Currency: $baseSymbol${_amountController.text.isEmpty ? '0.00' : _amountController.text}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
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
    if (!_attachLocation && widget.initialStoppageId == null) {
      _selectedStoppageId = null;
    }

    // Strict senior-dev financial integrity validation
    if (_splitType == SplitType.equal) {
      final includedCount = _equalIncluded.values.where((v) => v).length;
      if (includedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('At least one companion must be included in the bill split.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else if (_splitType == SplitType.exact) {
      final sum = splits.fold<double>(0, (acc, s) => acc + s.allocatedAmount);
      final diff = sum - totalAmount;
      if (diff.abs() > 0.01) {
        final symbol = CurrencyFormatter.getCurrencySymbol(trip.defaultCurrency);
        final status = diff > 0
            ? 'over-allocated by +$symbol${diff.toStringAsFixed(2)}'
            : 'under-allocated by -$symbol${(-diff).toStringAsFixed(2)}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Split sum ($symbol${sum.toStringAsFixed(2)}) does not match bill total ($symbol${totalAmount.toStringAsFixed(2)}). It is $status.'),
            backgroundColor: Colors.red[800],
          ),
        );
        return;
      }
    } else if (_splitType == SplitType.percentage) {
      double totalPct = 0.0;
      for (final member in trip.members) {
        totalPct += double.tryParse(_percentControllers[member.id]?.text ?? '0') ?? 0.0;
      }
      if ((totalPct - 100.0).abs() > 0.1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Percentages must sum to exactly 100.0% (Current sum: ${totalPct.toStringAsFixed(1)}%).'),
            backgroundColor: Colors.red[800],
          ),
        );
        return;
      }
    } else if (_splitType == SplitType.shares) {
      double totalShares = 0.0;
      for (final member in trip.members) {
        totalShares += double.tryParse(_sharesControllers[member.id]?.text ?? '0') ?? 0.0;
      }
      if (totalShares <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('At least one member must have shares greater than 0.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Build notes with location tag if enabled
    String? rawNotes = _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null;
    String? finalNotes = rawNotes;
    if (_attachLocation && _locationName != null && _locationName!.trim().isNotEmpty) {
      final locTag = '📍 Location: ${_locationName!.trim()}';
      if (finalNotes != null) {
        if (!finalNotes.contains('📍 Location:')) {
          finalNotes = '$finalNotes\n$locTag';
        }
      } else {
        finalNotes = locTag;
      }
    }

    // Prepare foreign currency conversion values if enabled
    double? originalAmount;
    String? originalCurrency;
    double? exchangeRate;
    if (_useForeignCurrency) {
      final parsedForeignAmt = double.tryParse(_foreignAmountController.text.trim());
      final parsedRate = double.tryParse(_exchangeRateController.text.trim());
      if (parsedForeignAmt != null && parsedForeignAmt > 0) {
        originalAmount = parsedForeignAmt;
        originalCurrency = _foreignCurrency;
        exchangeRate = (parsedRate != null && parsedRate > 0) ? parsedRate : null;
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
        notes: finalNotes,
        originalCurrency: originalCurrency,
        originalAmount: originalAmount,
        exchangeRate: exchangeRate,
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
        notes: finalNotes,
        originalCurrency: originalCurrency,
        originalAmount: originalAmount,
        exchangeRate: exchangeRate,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (trip == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }

    _initMemberSplits(trip.members);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Activity Bill' : 'Add Activity Bill / Expense'),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_rounded),
            tooltip: 'Scan Receipt with OCR',
            onPressed: _isScanningOcr ? null : _showOcrSourceDialog,
          ),
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
            // Smart OCR Quick-Fill Banner
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.primary.withAlpha(isDark ? 90 : 60),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isScanningOcr ? null : _showOcrSourceDialog,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withAlpha(isDark ? 50 : 35),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _isScanningOcr
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                                )
                              : const Icon(Icons.document_scanner_rounded, color: AppTheme.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _isScanningOcr ? 'Scanning Receipt...' : 'Scan Bill with Smart OCR',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withAlpha(isDark ? 40 : 30),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'AI / FAST',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isScanningOcr
                                    ? 'Extracting merchant, total amount & text...'
                                    : 'Auto-fills merchant & amount directly from photo',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Title & Amount
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Expense Title *',
                hintText: 'Enter expense title',
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
                      hintText: '0.00',
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
                    initialValue: AppConstants.expenseCategories.contains(_selectedCategory)
                        ? _selectedCategory
                        : AppConstants.expenseCategories.first,
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
            const SizedBox(height: 14),

            // Multi-Currency / Foreign Exchange Conversion Card (Issue 8)
            _buildCurrencyConversionCard(trip),
            const SizedBox(height: 14),

            // Payer & Split Section (Omitted for solo trips to maintain clean, professional UX)
            if (!trip.isSolo) ...[
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
              const SizedBox(height: 16),
            ],

            // Collapsible Split Method & Breakdown Card (Folded by default)
            if (!trip.isSolo) ...[
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isSplitExpanded
                        ? AppTheme.primary.withAlpha(isDark ? 160 : 120)
                        : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                    width: _isSplitExpanded ? 1.4 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Folded Summary Header (Always visible - tap to expand/collapse)
                    InkWell(
                      onTap: () {
                        setState(() => _isSplitExpanded = !_isSplitExpanded);
                        HapticFeedback.lightImpact();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withAlpha(isDark ? 35 : 20),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.call_split_rounded, color: AppTheme.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Split Method',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withAlpha(isDark ? 35 : 20),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _splitType == SplitType.equal
                                              ? 'Equally'
                                              : (_splitType == SplitType.exact
                                                  ? 'Exact'
                                                  : (_splitType == SplitType.percentage ? 'Percent %' : 'Shares')),
                                          style: const TextStyle(
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 10.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Builder(
                                    builder: (context) {
                                      final total = double.tryParse(_amountController.text.trim()) ?? 0.0;
                                      if (_splitType == SplitType.equal) {
                                        final incCount = _equalIncluded.values.where((v) => v).length;
                                        final perPerson = incCount > 0 ? (total / incCount) : 0.0;
                                        return Text(
                                          'Split among $incCount member${incCount == 1 ? "" : "s"}${total > 0 ? " • ${CurrencyFormatter.format(perPerson, currency: trip.defaultCurrency)} each" : ""}',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                          ),
                                        );
                                      } else if (_splitType == SplitType.exact) {
                                        return Text(
                                          'Custom exact amounts assigned',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                          ),
                                        );
                                      } else if (_splitType == SplitType.percentage) {
                                        return Text(
                                          'Percentage ratio allocation',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                          ),
                                        );
                                      } else {
                                        return Text(
                                          'Weighted shares allocation',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.black.withAlpha(10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _isSplitExpanded ? 'Fold' : 'Customize',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Icon(
                                    _isSplitExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    size: 16,
                                    color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expandable Configuration Body
                    if (_isSplitExpanded) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Select Split Calculation:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 8),
                            SegmentedButton<SplitType>(
                              segments: [
                                const ButtonSegment(value: SplitType.equal, label: Text('Equally')),
                                ButtonSegment(
                                  value: SplitType.exact,
                                  label: Text('Exact ${CurrencyFormatter.getCurrencySymbol(trip.defaultCurrency)}'),
                                ),
                                const ButtonSegment(value: SplitType.percentage, label: Text('Percent %')),
                                const ButtonSegment(value: SplitType.shares, label: Text('Shares')),
                              ],
                              selected: {_splitType},
                              onSelectionChanged: (val) {
                                setState(() => _splitType = val.first);
                              },
                            ),
                            const SizedBox(height: 14),

                            const Text('Member Cost Shares', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 10),
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
                                          onChanged: (_) => setState(() {}),
                                          decoration: InputDecoration(
                                            prefixText: '${CurrencyFormatter.getCurrencySymbol(trip.defaultCurrency)} ',
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else if (_splitType == SplitType.shares) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                                      SizedBox(
                                        width: 100,
                                        child: TextField(
                                          controller: _sharesControllers[m.id],
                                          keyboardType: const TextInputType.numberWithOptions(decimal: false),
                                          onChanged: (_) => setState(() {}),
                                          decoration: const InputDecoration(
                                            suffixText: 'share(s)',
                                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                                          onChanged: (_) => setState(() {}),
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
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            Builder(builder: (context) {
                              final total = double.tryParse(_amountController.text.trim()) ?? 0.0;
                              if (_splitType == SplitType.exact) {
                                double allocated = 0.0;
                                for (final m in trip.members) {
                                  allocated += double.tryParse(_exactControllers[m.id]?.text ?? '0') ?? 0.0;
                                }
                                final diff = allocated - total;
                                final isBalanced = (diff).abs() < 0.01;
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Allocated: ${CurrencyFormatter.format(allocated, currency: trip.defaultCurrency)} / ${CurrencyFormatter.format(total, currency: trip.defaultCurrency)}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: isBalanced ? Colors.green : Colors.red,
                                      ),
                                    ),
                                    Text(
                                      isBalanced ? '✓ Balanced' : (diff > 0 ? '+${CurrencyFormatter.format(diff, currency: trip.defaultCurrency)} over' : '-${CurrencyFormatter.format(-diff, currency: trip.defaultCurrency)} remaining'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isBalanced ? Colors.green : Colors.red,
                                      ),
                                    ),
                                  ],
                                );
                              } else if (_splitType == SplitType.percentage) {
                                double totalPct = 0.0;
                                for (final m in trip.members) {
                                  totalPct += double.tryParse(_percentControllers[m.id]?.text ?? '0') ?? 0.0;
                                }
                                final isBalanced = (totalPct - 100.0).abs() < 0.1;
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total: ${totalPct.toStringAsFixed(1)}% / 100.0%',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: isBalanced ? Colors.green : Colors.orange[800],
                                      ),
                                    ),
                                    Text(
                                      isBalanced ? '✓ 100% Allocated' : '${(100.0 - totalPct).toStringAsFixed(1)}% remaining',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isBalanced ? Colors.green : Colors.orange[800],
                                      ),
                                    ),
                                  ],
                                );
                              } else if (_splitType == SplitType.shares) {
                                double totalShares = 0.0;
                                for (final m in trip.members) {
                                  totalShares += double.tryParse(_sharesControllers[m.id]?.text ?? '0') ?? 0.0;
                                }
                                final perShare = totalShares > 0 ? (total / totalShares) : 0.0;
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total Shares: ${totalShares.toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                    ),
                                    Text(
                                      '${CurrencyFormatter.format(perShare, currency: trip.defaultCurrency)} / share',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                    ),
                                  ],
                                );
                              } else {
                                final incCount = _equalIncluded.values.where((v) => v).length;
                                final perPerson = incCount > 0 ? (total / incCount) : 0.0;
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Splitting among $incCount member${incCount == 1 ? "" : "s"}',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                    ),
                                    Text(
                                      '${CurrencyFormatter.format(perPerson, currency: trip.defaultCurrency)} each',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                    ),
                                  ],
                                );
                              }
                            }),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Location Tagging Section (Toggle)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _attachLocation ? const Color(0xFF0EA5E9).withAlpha(120) : Colors.grey.withAlpha(50),
                  width: _attachLocation ? 1.5 : 1.0,
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
                            Icons.place_rounded,
                            size: 18,
                            color: _attachLocation ? const Color(0xFF0EA5E9) : AppTheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Attach Location (GPS / Map)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      Switch(
                        value: _attachLocation,
                        activeThumbColor: const Color(0xFF0EA5E9),
                        onChanged: (val) {
                          setState(() {
                            _attachLocation = val;
                            if (val && _locationName == null) {
                              _detectCurrentLocation();
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  if (_attachLocation) ...[
                    const SizedBox(height: 10),
                    if (_locationName != null && _locationName!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0EA5E9).withAlpha(18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF0EA5E9).withAlpha(60)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: Color(0xFF0EA5E9), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _locationName!,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_latitude != null && _longitude != null)
                                    Text(
                                      'GPS: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                                      style: TextStyle(fontSize: 10.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                              onPressed: () => setState(() {
                                _locationName = null;
                                _latitude = null;
                                _longitude = null;
                              }),
                              tooltip: 'Clear location',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isDetectingLocation ? null : _detectCurrentLocation,
                            icon: _isDetectingLocation
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.my_location_rounded, size: 16),
                            label: Text(
                              _isDetectingLocation ? 'Detecting...' : 'Current GPS',
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickLocationOnMap,
                            icon: const Icon(Icons.map_rounded, size: 16),
                            label: const Text('Pick on Map', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

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
                            'Attach Bill / Receipt Photo',
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
                        InkWell(
                          onTap: () => _showReceiptFullscreen(context, _receiptImagePath!),
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: _buildReceiptThumbnail(_receiptImagePath!),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.only(topLeft: Radius.circular(6)),
                                ),
                                child: const Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bill photo attached',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Tap photo thumbnail to zoom',
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: _isScanningOcr ? null : _showOcrSourceDialog,
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
                            onPressed: _isScanningOcr ? null : () => _scanReceiptWithOcr(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_rounded, size: 16, color: AppTheme.primary),
                            label: const Text('Scan with Camera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              side: BorderSide(color: AppTheme.primary.withAlpha(120)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isScanningOcr ? null : () => _scanReceiptWithOcr(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded, size: 16),
                            label: const Text('Upload from Gallery', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
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
                hintText: 'Add invoice notes or details (optional)',
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
