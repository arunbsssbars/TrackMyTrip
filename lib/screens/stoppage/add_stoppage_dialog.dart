import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/trip_audit_log.dart';
import '../../models/expense.dart';
import '../../models/expense_split.dart';
import '../../models/memory.dart';
import '../../models/nearby_poi.dart';
import '../../models/stoppage.dart';
import '../../providers/audit_log_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';
import 'map_location_picker_dialog.dart';

class AddStoppageDialog extends ConsumerStatefulWidget {
  final String tripId;
  final LatLng? initialPosition;
  final String? initialPlaceName;
  final String? initialCategory;
  final bool autoDetectGps;

  const AddStoppageDialog({
    super.key,
    required this.tripId,
    this.initialPosition,
    this.initialPlaceName,
    this.initialCategory,
    this.autoDetectGps = true,
  });

  static Future<void> show(
    BuildContext context, {
    required String tripId,
    LatLng? initialPosition,
    String? initialPlaceName,
    String? initialCategory,
    bool autoDetectGps = true,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddStoppageDialog(
        tripId: tripId,
        initialPosition: initialPosition,
        initialPlaceName: initialPlaceName,
        initialCategory: initialCategory,
        autoDetectGps: autoDetectGps,
      ),
    );
  }

  static String mapStoppageToExpenseCategory(String stoppageCategory) {
    switch (stoppageCategory) {
      case 'Gas / Fuel Station':
      case 'Fuel Pump':
      case 'Gas Station':
      case 'Petrol Pump':
        return 'Fuel / Gas';
      case 'Food & Cafe':
      case 'Restaurant':
        return 'Food & Drinks';
      case 'Hotel & Stay':
      case 'Lodge':
        return 'Accommodation';
      case 'Toll & Transit':
      case 'Toll Plaza':
        return 'Transport & Toll';
      case 'Adventure & Activity':
      case 'Sightseeing':
        return 'Activities & Tickets';
      case 'Shopping':
        return 'Shopping & Souvenirs';
      case 'Rest Stop':
        return 'Snacks & Refreshment';
      case 'Hospital / Clinic':
      case 'Emergency':
        return 'Emergency & Misc';
      default:
        return 'Emergency & Misc';
    }
  }

  @override
  ConsumerState<AddStoppageDialog> createState() => _AddStoppageDialogState();
}

class _AddStoppageDialogState extends ConsumerState<AddStoppageDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _latController = TextEditingController(text: '28.4990');
  final _lngController = TextEditingController(text: '77.5330');

  // In-Stoppage Bill Creation State
  bool _attachBill = false;
  final _billAmountController = TextEditingController();
  final _billTitleController = TextEditingController();
  String? _selectedExpenseCategory;
  String? _paidByMemberId;
  final Set<String> _splitIncludedMemberIds = {};
  String? _receiptImagePath;
  bool _isLoadingReceipt = false;
  bool _hasInitializedMembers = false;

  String _selectedCategory = AppConstants.stoppageCategories.first;
  DateTime _arrivedAt = DateTime.now();
  bool _isOngoing = true;
  bool _isDetectingLocation = false;
  final List<String> _attachedPhotos = [];
  bool _isLoadingImage = false;
  List<NearbyPOI> _nearbyPOIs = [];
  bool _isLoadingPOIs = false;

  static String mapStoppageToExpenseCategory(String stoppageCategory) =>
      AddStoppageDialog.mapStoppageToExpenseCategory(stoppageCategory);

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    _selectedExpenseCategory = mapStoppageToExpenseCategory(_selectedCategory);

    if (widget.initialPlaceName != null) {
      _nameController.text = widget.initialPlaceName!;
    }
    if (widget.initialPosition != null) {
      _latController.text = widget.initialPosition!.latitude.toStringAsFixed(6);
      _lngController.text = widget.initialPosition!.longitude.toStringAsFixed(6);
      if (widget.initialPlaceName == null) {
        _reverseGeocode(widget.initialPosition!.latitude, widget.initialPosition!.longitude);
      }
    } else if (widget.autoDetectGps) {
      _detectCurrentLocation();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _billAmountController.dispose();
    _billTitleController.dispose();
    super.dispose();
  }

  Future<void> _pickReceiptPhoto(ImageSource source) async {
    try {
      setState(() => _isLoadingReceipt = true);
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
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
          SnackBar(content: Text('Could not load receipt: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingReceipt = false);
      }
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      setState(() => _isLoadingImage = true);
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (picked != null) {
        if (kIsWeb) {
          final bytes = await picked.readAsBytes();
          final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
          setState(() => _attachedPhotos.add(base64String));
        } else {
          setState(() => _attachedPhotos.add(picked.path));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingImage = false);
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add Photo Memory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _pickPhoto(ImageSource.camera);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withAlpha(25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: AppTheme.primary, size: 28),
                          ),
                          const SizedBox(height: 8),
                          const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _pickPhoto(ImageSource.gallery);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.secondary.withAlpha(25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.photo_library_rounded, color: AppTheme.secondary, size: 28),
                          ),
                          const SizedBox(height: 8),
                          const Text('From Gallery', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReceiptSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Attach Bill Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _pickReceiptPhoto(ImageSource.camera);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withAlpha(25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF10B981), size: 28),
                          ),
                          const SizedBox(height: 8),
                          const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _pickReceiptPhoto(ImageSource.gallery);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withAlpha(25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.photo_library_rounded, color: AppTheme.primary, size: 28),
                          ),
                          const SizedBox(height: 8),
                          const Text('From Gallery', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail(String path, int index) {
    Widget imageWidget;
    if (path.startsWith('data:image')) {
      final base64Str = path.split(',').last;
      imageWidget = Image.memory(base64Decode(base64Str), fit: BoxFit.cover);
    } else if (path.startsWith('http://') || path.startsWith('https://')) {
      imageWidget = Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)));
    } else if (!kIsWeb) {
      imageWidget = Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)));
    } else {
      imageWidget = const Center(child: Icon(Icons.photo_rounded));
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 68,
            height: 68,
            child: imageWidget,
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: () => setState(() => _attachedPhotos.removeAt(index)),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _detectCurrentLocation() async {
    setState(() => _isDetectingLocation = true);

    final pos = await LocationService.getCurrentPosition();
    if (pos != null && mounted) {
      _latController.text = pos.latitude.toStringAsFixed(6);
      _lngController.text = pos.longitude.toStringAsFixed(6);
      await _reverseGeocode(pos.latitude, pos.longitude);
    }

    if (mounted) {
      setState(() => _isDetectingLocation = false);
    }
  }

  Future<void> _fetchNearbyPOIs(double lat, double lng) async {
    if (!mounted) return;
    setState(() => _isLoadingPOIs = true);
    try {
      final results = await LocationService.fetchNearbyPOIs(lat, lng);
      if (mounted) {
        setState(() {
          _nearbyPOIs = results;
          _isLoadingPOIs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPOIs = false);
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    _fetchNearbyPOIs(lat, lng);
    final details = await LocationService.reverseGeocode(lat, lng);
    if (mounted) {
      if (_nameController.text.trim().isEmpty || _nameController.text.startsWith('Waypoint') || _nameController.text == 'Highway Pitstop') {
        _nameController.text = details.placeName;
      }
      if (details.address != null && _addressController.text.trim().isEmpty) {
        _addressController.text = details.address!;
      }
      if (details.category != null && AppConstants.stoppageCategories.contains(details.category)) {
        setState(() => _selectedCategory = details.category!);
      }
    }
  }

  Future<void> _openMapPicker() async {
    final curLat = double.tryParse(_latController.text) ?? 28.4990;
    final curLng = double.tryParse(_lngController.text) ?? 77.5330;

    final picked = await MapLocationPickerDialog.show(
      context,
      initialPosition: LatLng(curLat, curLng),
    );

    if (picked != null && mounted) {
      setState(() {
        _latController.text = picked.latitude.toStringAsFixed(6);
        _lngController.text = picked.longitude.toStringAsFixed(6);
        _nameController.text = picked.placeName;
        if (picked.address != null) {
          _addressController.text = picked.address!;
        }
        if (picked.category != null && AppConstants.stoppageCategories.contains(picked.category)) {
          _selectedCategory = picked.category!;
        }
      });
      _fetchNearbyPOIs(picked.latitude, picked.longitude);
    }
  }

  Future<void> _pickArrivalTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _arrivedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_arrivedAt),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _arrivedAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // If attaching a bill, validate amount
    double? billAmount;
    if (_attachBill) {
      final amtText = _billAmountController.text.trim();
      billAmount = double.tryParse(amtText);
      if (billAmount == null || billAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid bill amount or turn off "Attach Bill".'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final currentTrip = ref.read(currentTripProvider);
    final myMemberId = currentTrip?.currentUserMember?.id ?? 'me';

    final lat = double.tryParse(_latController.text) ?? 28.4990;
    final lng = double.tryParse(_lngController.text) ?? 77.5330;

    final newStoppage = Stoppage(
      id: const Uuid().v4(),
      tripId: widget.tripId,
      name: _nameController.text.trim(),
      latitude: lat,
      longitude: lng,
      address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
      category: _selectedCategory,
      arrivedAt: _arrivedAt,
      departedAt: _isOngoing ? null : _arrivedAt.add(const Duration(minutes: 45)),
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      createdBy: myMemberId,
    );

    ref.read(allStoppagesProvider.notifier).addStoppage(newStoppage);

    // Save attached photo memories
    for (final photoPath in _attachedPhotos) {
      final memory = Memory(
        id: const Uuid().v4(),
        tripId: widget.tripId,
        stoppageId: newStoppage.id,
        uploadedByMemberId: myMemberId,
        mediaPath: photoPath,
        caption: 'Captured at ${newStoppage.name}',
        createdAt: DateTime.now(),
      );
      ref.read(allMemoriesProvider.notifier).addMemory(memory);
    }

    // Save attached bill if enabled
    if (_attachBill && billAmount != null && currentTrip != null) {
      final payerId = _paidByMemberId ?? myMemberId;
      final expenseCategory = _selectedExpenseCategory ?? mapStoppageToExpenseCategory(_selectedCategory);
      final rawTitle = _billTitleController.text.trim();
      final title = rawTitle.isNotEmpty ? rawTitle : 'Bill at ${newStoppage.name}';

      // Build equal splits among selected members
      final includedMembers = currentTrip.members
          .where((m) => _splitIncludedMemberIds.contains(m.id))
          .toList();
      final splitCount = includedMembers.isEmpty ? currentTrip.members.length : includedMembers.length;
      final perPerson = billAmount / splitCount;

      final splits = currentTrip.members.map((m) {
        final isInc = _splitIncludedMemberIds.isEmpty || _splitIncludedMemberIds.contains(m.id);
        return ExpenseSplit(
          memberId: m.id,
          allocatedAmount: isInc ? perPerson : 0.0,
          isIncluded: isInc,
        );
      }).toList();

      final newExpense = Expense(
        id: const Uuid().v4(),
        tripId: widget.tripId,
        stoppageId: newStoppage.id,
        title: title,
        totalAmount: billAmount,
        currency: currentTrip.defaultCurrency,
        category: expenseCategory,
        paidByMemberId: payerId,
        splitType: SplitType.equal,
        splits: splits,
        receiptImagePath: _receiptImagePath ?? (_attachedPhotos.isNotEmpty ? _attachedPhotos.first : null),
        notes: 'Attached during stop tagging at ${newStoppage.name}',
        createdAt: _arrivedAt,
      );

      ref.read(allExpensesProvider.notifier).addExpense(newExpense);

      // Audit Log for the expense
      final currentMember = currentTrip.currentUserMember;
      ref.read(allAuditLogsProvider.notifier).logAction(
        TripAuditLog(
          id: const Uuid().v4(),
          tripId: widget.tripId,
          actionType: 'create_expense',
          itemTitle: newExpense.title,
          performedByMemberId: currentMember?.id ?? myMemberId,
          performedByName: currentMember?.name ?? 'Traveler',
          timestamp: DateTime.now(),
          changeDetails: 'Added bill of ${CurrencyFormatter.format(newExpense.totalAmount, currency: currentTrip.defaultCurrency)} for stoppage "${newStoppage.name}"',
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Tagged "${newStoppage.name}" & saved bill of ${CurrencyFormatter.format(billAmount, currency: currentTrip.defaultCurrency)}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Tagged stoppage "${newStoppage.name}"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final trip = ref.watch(currentTripProvider);

    if (!_hasInitializedMembers && trip != null && trip.members.isNotEmpty) {
      _hasInitializedMembers = true;
      _splitIncludedMemberIds.addAll(trip.members.map((m) => m.id));
      _paidByMemberId ??= trip.currentUserMember?.id ?? trip.members.first.id;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_location_alt_rounded, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tag Stoppage',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.3),
                      ),
                      Text(
                        'Record milestone, cafe, stay or scenic view',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content Form
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                children: [
                  // Location Detection Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Location Detection',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            if (_isDetectingLocation)
                              const Row(
                                children: [
                                  SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Detecting GPS...',
                                    style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isDetectingLocation ? null : _detectCurrentLocation,
                                icon: const Icon(Icons.my_location_rounded, size: 16),
                                label: const Text('Detect GPS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  side: const BorderSide(color: AppTheme.primary, width: 1.2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _openMapPicker,
                                icon: const Icon(Icons.map_rounded, size: 16),
                                label: const Text('Choose on Map', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.secondary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black26 : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.withAlpha(40)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.explore_rounded, size: 14, color: Colors.grey),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'GPS: ${_latController.text}, ${_lngController.text}',
                                  style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: isDark ? Colors.grey[300] : Colors.grey[700]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Nearby Tagged Places Suggestions
                  if (_isLoadingPOIs || _nearbyPOIs.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.near_me_rounded, size: 13, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        const Text(
                          'Nearby Tagged Places',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        if (_isLoadingPOIs) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                        ] else ...[
                          const SizedBox(width: 6),
                          Text(
                            '(${_nearbyPOIs.length} found)',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _nearbyPOIs.map((poi) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              avatar: Icon(poi.icon, size: 14, color: AppTheme.primary),
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    poi.name,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withAlpha(25),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      poi.formattedDistance,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              onPressed: () {
                                setState(() {
                                  _nameController.text = poi.name;
                                  _latController.text = poi.latitude.toStringAsFixed(6);
                                  _lngController.text = poi.longitude.toStringAsFixed(6);
                                  if (AppConstants.stoppageCategories.contains(poi.category)) {
                                    _selectedCategory = poi.category;
                                  }
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Selected: ${poi.name}'),
                                    duration: const Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Place Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Stoppage / Place Name *',
                      hintText: 'e.g. McWay Falls, Starbucks Midway',
                      prefixIcon: Icon(Icons.place_rounded),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Please enter place name' : null,
                  ),
                  const SizedBox(height: 12),

                  // Category Selector (Clean Choice Chips)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Category',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: AppConstants.stoppageCategories.map((c) {
                            final isSelected = _selectedCategory == c;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                showCheckmark: false,
                                label: Text(c, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                avatar: Icon(AppConstants.getStoppageIcon(c), size: 14, color: isSelected ? Colors.white : AppTheme.primary),
                                selected: isSelected,
                                selectedColor: AppTheme.primary,
                                labelStyle: TextStyle(color: isSelected ? Colors.white : null),
                                onSelected: (_) => setState(() => _selectedCategory = c),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                visualDensity: VisualDensity.compact,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Address / Landmark
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address / Landmark (Optional)',
                      hintText: 'Highway 1, Monterey County',
                      prefixIcon: Icon(Icons.location_city_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Arrived At Picker
                  InkWell(
                    onTap: _pickArrivalTime,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_filled_rounded, color: AppTheme.primary, size: 20),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Arrival Timestamp', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              Text(
                                DateFormatter.formatDateTime(_arrivedAt),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Ongoing Stop toggle
                  SwitchListTile(
                    title: const Text('Currently Stopped Here', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Keep stoppage active until you depart', style: TextStyle(fontSize: 10)),
                    value: _isOngoing,
                    activeColor: AppTheme.secondary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _isOngoing = val),
                  ),

                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Vibe (Optional)',
                      hintText: 'What happened here? Quick notes...',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),

                  // Photos & Memories Upload Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.photo_camera_back_rounded, size: 16, color: AppTheme.secondary),
                                const SizedBox(width: 6),
                                Text(
                                  'Attach Photos / Memories (${_attachedPhotos.length})',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            OutlinedButton.icon(
                              onPressed: _isLoadingImage ? null : _showImageSourcePicker,
                              icon: _isLoadingImage
                                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.add_a_photo_rounded, size: 14),
                              label: const Text('Add Photo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                                side: const BorderSide(color: AppTheme.secondary, width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                        if (_attachedPhotos.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 72,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _attachedPhotos.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, idx) => _buildPhotoThumbnail(_attachedPhotos[idx], idx),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          Text(
                            'Photos attached here will appear in your Memories tab automatically.',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : AppTheme.textMutedLight),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ============================================
                  // ATTACH BILL / EXPENSE (Senior Developer Architecture)
                  // ============================================
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _attachBill
                          ? (isDark ? const Color(0xFF0F291E) : const Color(0xFFF0FDF4))
                          : (isDark ? AppTheme.surfaceMutedDark : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _attachBill
                            ? const Color(0xFF10B981)
                            : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
                        width: _attachBill ? 1.4 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: _attachBill
                                    ? const Color(0xFF10B981).withAlpha(30)
                                    : (isDark ? Colors.white10 : Colors.black.withAlpha(10)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.receipt_long_rounded,
                                size: 18,
                                color: _attachBill ? const Color(0xFF10B981) : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Attach Bill / Expense',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                                      ),
                                      if (_attachBill) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withAlpha(30),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: const Text(
                                            'Active',
                                            style: TextStyle(fontSize: 9, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    'Split fuel, food, tickets or stay for this stop',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _attachBill,
                              activeColor: const Color(0xFF10B981),
                              onChanged: (val) {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _attachBill = val;
                                  if (val && _billTitleController.text.trim().isEmpty && _nameController.text.trim().isNotEmpty) {
                                    _billTitleController.text = 'Bill at ${_nameController.text.trim()}';
                                  }
                                });
                              },
                            ),
                          ],
                        ),

                        if (_attachBill) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),

                          // Amount field
                          TextFormField(
                            controller: _billAmountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            decoration: InputDecoration(
                              labelText: 'Total Bill Amount *',
                              hintText: '0.00',
                              prefixText: '${CurrencyFormatter.getCurrencySymbol(trip?.defaultCurrency ?? "INR")} ',
                              prefixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              prefixIcon: const Icon(Icons.payments_outlined),
                            ),
                            validator: (val) {
                              if (!_attachBill) return null;
                              if (val == null || val.trim().isEmpty) return 'Enter bill amount';
                              final numVal = double.tryParse(val.trim());
                              if (numVal == null || numVal <= 0) return 'Enter valid amount';
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          // Bill Title
                          TextFormField(
                            controller: _billTitleController,
                            decoration: InputDecoration(
                              labelText: 'Bill Title (Optional)',
                              hintText: _nameController.text.trim().isNotEmpty
                                  ? 'Bill at ${_nameController.text.trim()}'
                                  : 'e.g. Fuel Refill, Lunch, Toll',
                              prefixIcon: const Icon(Icons.title_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Expense Category Selector
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Expense Category',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                              const SizedBox(height: 6),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: AppConstants.expenseCategories.map((cat) {
                                    final isSelected = _selectedExpenseCategory == cat;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ChoiceChip(
                                        showCheckmark: false,
                                        label: Text(
                                          cat,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                        selected: isSelected,
                                        selectedColor: const Color(0xFF10B981),
                                        labelStyle: TextStyle(color: isSelected ? Colors.white : null),
                                        onSelected: (_) => setState(() => _selectedExpenseCategory = cat),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Payer Selection
                          if (trip != null && trip.members.isNotEmpty) ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Paid By',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                                ),
                                const SizedBox(height: 6),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: trip.members.map((m) {
                                      final isPayer = _paidByMemberId == m.id || (_paidByMemberId == null && m.isCurrentUser);
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: ChoiceChip(
                                          avatar: CircleAvatar(
                                            backgroundColor: isPayer ? Colors.white : AppTheme.primary,
                                            child: Text(
                                              m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isPayer ? AppTheme.primary : Colors.white,
                                              ),
                                            ),
                                          ),
                                          label: Text(
                                            m.isCurrentUser ? 'You (${m.name})' : m.name,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: isPayer ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                          selected: isPayer,
                                          selectedColor: AppTheme.primary,
                                          labelStyle: TextStyle(color: isPayer ? Colors.white : null),
                                          onSelected: (_) => setState(() => _paidByMemberId = m.id),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Split Among Members
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Split Equally (${_splitIncludedMemberIds.isEmpty ? trip.members.length : _splitIncludedMemberIds.length} members)',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          if (_splitIncludedMemberIds.length == trip.members.length) {
                                            _splitIncludedMemberIds.clear();
                                            if (trip.currentUserMember != null) {
                                              _splitIncludedMemberIds.add(trip.currentUserMember!.id);
                                            }
                                          } else {
                                            _splitIncludedMemberIds.addAll(trip.members.map((m) => m.id));
                                          }
                                        });
                                      },
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        _splitIncludedMemberIds.length == trip.members.length ? 'Only Me' : 'Select All',
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: trip.members.map((m) {
                                    final isInc = _splitIncludedMemberIds.contains(m.id);
                                    return FilterChip(
                                      label: Text(m.isCurrentUser ? 'You' : m.name, style: const TextStyle(fontSize: 10.5)),
                                      selected: isInc,
                                      selectedColor: const Color(0xFF10B981).withAlpha(40),
                                      checkmarkColor: const Color(0xFF10B981),
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            _splitIncludedMemberIds.add(m.id);
                                          } else {
                                            if (_splitIncludedMemberIds.length > 1) {
                                              _splitIncludedMemberIds.remove(m.id);
                                            }
                                          }
                                        });
                                      },
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      visualDensity: VisualDensity.compact,
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),

                          // Receipt Attachment Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.receipt_rounded, size: 14, color: Colors.grey),
                                  SizedBox(width: 5),
                                  Text(
                                    'Bill Receipt Photo',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                                  ),
                                ],
                              ),
                              if (_receiptImagePath != null)
                                TextButton.icon(
                                  onPressed: () => setState(() => _receiptImagePath = null),
                                  icon: const Icon(Icons.close_rounded, size: 13, color: Colors.red),
                                  label: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 10.5)),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                )
                              else
                                OutlinedButton.icon(
                                  onPressed: _isLoadingReceipt ? null : _showReceiptSourcePicker,
                                  icon: _isLoadingReceipt
                                      ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5))
                                      : const Icon(Icons.add_photo_alternate_rounded, size: 13),
                                  label: const Text('Attach Receipt', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                    side: const BorderSide(color: Color(0xFF10B981), width: 1),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                            ],
                          ),
                          if (_receiptImagePath != null) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                height: 80,
                                width: 80,
                                child: _buildPhotoThumbnail(_receiptImagePath!, 0),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _submit,
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Save Stoppage', style: TextStyle(fontWeight: FontWeight.bold)),
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
          ),
        ],
      ),
    );
  }
}
