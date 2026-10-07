import 'package:flutter/material.dart';
import '../../models/vehicle_maintenance_milestone.dart';

class VehicleMaintenanceService {
  static final VehicleMaintenanceService _instance = VehicleMaintenanceService._internal();
  factory VehicleMaintenanceService() => _instance;
  VehicleMaintenanceService._internal();

  /// Calculates net distance travelled between first and latest odometer readings
  double calculateOdometerDistance(List<VehicleMaintenanceMilestone> milestones) {
    if (milestones.length < 2) return 0.0;
    final sorted = List<VehicleMaintenanceMilestone>.from(milestones)
      ..sort((a, b) => a.odometerKm.compareTo(b.odometerKm));
    return (sorted.last.odometerKm - sorted.first.odometerKm).clamp(0.0, 999999.0);
  }

  /// Calculates total monetary cost of all maintenance & toll events
  double calculateTotalCost(List<VehicleMaintenanceMilestone> milestones) {
    return milestones.fold<double>(0.0, (acc, m) => acc + m.cost);
  }

  static IconData getMilestoneIcon(String milestoneType) {
    switch (milestoneType.toLowerCase()) {
      case 'toll':
        return Icons.toll_rounded;
      case 'fuel_topup':
        return Icons.local_gas_station_rounded;
      case 'tyre_check':
        return Icons.tire_repair_rounded;
      case 'oil_service':
        return Icons.car_repair_rounded;
      case 'breakdown':
        return Icons.warning_rounded;
      default:
        return Icons.build_circle_rounded;
    }
  }

  static String getMilestoneLabel(String milestoneType) {
    switch (milestoneType.toLowerCase()) {
      case 'toll':
        return 'Toll / Fastag';
      case 'fuel_topup':
        return 'Fuel Top-up';
      case 'tyre_check':
        return 'Tyre Inspection';
      case 'oil_service':
        return 'Engine Oil & Fluids';
      case 'breakdown':
        return 'Breakdown / Repair';
      default:
        return 'General Service';
    }
  }
}
