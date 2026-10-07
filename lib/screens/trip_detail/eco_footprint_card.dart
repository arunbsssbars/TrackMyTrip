import 'package:flutter/material.dart';
import '../../models/eco_footprint_telemetry.dart';
import '../../core/services/eco_telemetry_service.dart';

class EcoFootprintCard extends StatefulWidget {
  final double distanceKm;
  final String initialVehicleType;
  final ValueChanged<EcoFootprintTelemetry>? onTelemetryChanged;

  const EcoFootprintCard({
    super.key,
    required this.distanceKm,
    this.initialVehicleType = 'Diesel SUV',
    this.onTelemetryChanged,
  });

  @override
  State<EcoFootprintCard> createState() => _EcoFootprintCardState();
}

class _EcoFootprintCardState extends State<EcoFootprintCard> {
  late String _selectedVehicle;
  late EcoFootprintTelemetry _telemetry;

  @override
  void initState() {
    super.initState();
    _selectedVehicle = widget.initialVehicleType;
    _recalculate();
  }

  void _recalculate() {
    _telemetry = EcoTelemetryService().calculateTelemetry(
      distanceKm: widget.distanceKm,
      vehicleType: _selectedVehicle,
    );
    widget.onTelemetryChanged?.call(_telemetry);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEv = _selectedVehicle == 'Electric EV';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.teal.withAlpha(40),
                  child: Icon(Icons.eco_rounded, color: Colors.teal.shade700, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Carbon Footprint & Fuel',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Total Distance: ${widget.distanceKm.toStringAsFixed(1)} km',
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
            const SizedBox(height: 14),

            // Vehicle Powertrain Selector Dropdown with isExpanded: true (AQIL Safe)
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedVehicle,
              decoration: InputDecoration(
                labelText: 'Convoy Powertrain',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: EcoTelemetryService.supportedVehicleTypes
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(v, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedVehicle = val;
                    _recalculate();
                  });
                }
              },
            ),
            const SizedBox(height: 14),

            // Metrics Grid (Responsive Wrap)
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _buildMetricChip(
                  context,
                  icon: Icons.cloud_outlined,
                  label: 'CO₂ Emitted',
                  value: '${_telemetry.co2EmittedKg} kg',
                  color: Colors.brown.shade600,
                ),
                _buildMetricChip(
                  context,
                  icon: isEv ? Icons.electric_bolt_rounded : Icons.local_gas_station_rounded,
                  label: isEv ? 'Energy Used' : 'Fuel Burned',
                  value: '${_telemetry.fuelBurnedLitres} ${isEv ? 'kWh' : 'L'}',
                  color: isEv ? Colors.blue : Colors.deepOrange,
                ),
                _buildMetricChip(
                  context,
                  icon: Icons.currency_rupee_rounded,
                  label: 'Est. Fuel Cost',
                  value: '${_telemetry.currencyCode} ${_telemetry.estimatedFuelCost.toStringAsFixed(0)}',
                  color: Colors.indigo,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Tree offset banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.park_rounded, color: Colors.teal.shade800, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Plant ${_telemetry.treesRequiredToOffset} ${_telemetry.treesRequiredToOffset == 1 ? 'tree' : 'trees'} to offset this expedition\'s emissions.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal.shade900,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 100),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withAlpha(220),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
