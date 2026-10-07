import 'package:flutter/material.dart';
import '../../models/vehicle_maintenance_milestone.dart';
import '../../core/services/vehicle_maintenance_service.dart';

class VehicleMaintenanceSheet extends StatefulWidget {
  final String tripId;
  final String vehicleName;
  final List<VehicleMaintenanceMilestone> initialMilestones;
  final ValueChanged<List<VehicleMaintenanceMilestone>>? onMilestonesChanged;

  const VehicleMaintenanceSheet({
    super.key,
    required this.tripId,
    required this.vehicleName,
    required this.initialMilestones,
    this.onMilestonesChanged,
  });

  @override
  State<VehicleMaintenanceSheet> createState() => _VehicleMaintenanceSheetState();
}

class _VehicleMaintenanceSheetState extends State<VehicleMaintenanceSheet> {
  late List<VehicleMaintenanceMilestone> _milestones;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final String _selectedType = 'toll';

  @override
  void initState() {
    super.initState();
    _milestones = List.from(widget.initialMilestones);
  }

  @override
  void dispose() {
    _noteController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _addMilestone() {
    final note = _noteController.text.trim();
    final cost = double.tryParse(_costController.text.trim()) ?? 0.0;
    final lastOdo = _milestones.isNotEmpty ? _milestones.last.odometerKm : 10000.0;

    final newMilestone = VehicleMaintenanceMilestone(
      id: 'm_${DateTime.now().millisecondsSinceEpoch}',
      tripId: widget.tripId,
      vehicleName: widget.vehicleName,
      odometerKm: lastOdo + 50.0,
      milestoneType: _selectedType,
      cost: cost,
      notes: note.isNotEmpty ? note : VehicleMaintenanceService.getMilestoneLabel(_selectedType),
      recordedAt: DateTime.now(),
    );

    setState(() {
      _milestones.add(newMilestone);
      _noteController.clear();
      _costController.clear();
    });
    widget.onMilestonesChanged?.call(_milestones);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distance = VehicleMaintenanceService().calculateOdometerDistance(_milestones);
    final totalCost = VehicleMaintenanceService().calculateTotalCost(_milestones);
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
                child: Icon(Icons.build_rounded, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehicle & Toll Log: ${widget.vehicleName}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${_milestones.length} milestones • Total: ₹${totalCost.toStringAsFixed(0)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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

          // Odometer Tracker Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Trip Odometer Delta',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${distance.toStringAsFixed(1)} km',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Milestone list
          Flexible(
            child: _milestones.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'No maintenance or toll milestones recorded yet.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _milestones.length,
                    itemBuilder: (context, index) {
                      final item = _milestones[index];
                      final icon = VehicleMaintenanceService.getMilestoneIcon(item.milestoneType);
                      final label = VehicleMaintenanceService.getMilestoneLabel(item.milestoneType);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        elevation: 0,
                        color: theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Icon(icon, size: 20, color: theme.colorScheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.notes.isNotEmpty ? item.notes : label,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Odo: ${item.odometerKm.toStringAsFixed(0)} km',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (item.cost > 0)
                                Text(
                                  '${item.currency} ${item.cost.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),

          // Quick input row for new log
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    hintText: 'Note (e.g. Fastag toll)...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _costController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Cost (₹)',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: _addMilestone,
                icon: const Icon(Icons.add, size: 20),
                tooltip: 'Add Milestone',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
