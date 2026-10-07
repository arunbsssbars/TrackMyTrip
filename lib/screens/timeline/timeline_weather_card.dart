import 'package:flutter/material.dart';
import '../../models/weather_altitude_telemetry.dart';
import '../../core/services/weather_altitude_service.dart';

class TimelineWeatherCard extends StatefulWidget {
  final WeatherAltitudeTelemetry telemetry;
  final String? ascentWarning;
  final VoidCallback? onRefresh;

  const TimelineWeatherCard({
    super.key,
    required this.telemetry,
    this.ascentWarning,
    this.onRefresh,
  });

  @override
  State<TimelineWeatherCard> createState() => _TimelineWeatherCardState();
}

class _TimelineWeatherCardState extends State<TimelineWeatherCard> {
  bool _useImperial = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final telemetry = widget.telemetry;
    final conditionIcon = WeatherAltitudeService.getConditionIcon(telemetry.condition);
    final conditionColor = WeatherAltitudeService.getConditionColor(telemetry.condition);

    final tempString = _useImperial
        ? '${telemetry.temperatureFahrenheit.toStringAsFixed(1)}°F'
        : '${telemetry.temperatureCelsius.toStringAsFixed(1)}°C';

    final altString = _useImperial
        ? '${telemetry.altitudeFeet.toStringAsFixed(0)} ft'
        : '${telemetry.altitudeMeters.toStringAsFixed(0)} m';

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
            // Top Bar: Weather condition + Units toggle
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: conditionColor.withAlpha(40),
                  child: Icon(conditionIcon, color: conditionColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        telemetry.condition,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Live Expedition Telemetry',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _useImperial = !_useImperial;
                    });
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(44, 44),
                  ),
                  child: Text(
                    _useImperial ? 'Imperial' : 'Metric',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Metrics Grid (Responsive Wrap for small screen safe layout)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildMetricChip(
                  context,
                  icon: Icons.thermostat_rounded,
                  label: 'Temp',
                  value: tempString,
                  color: Colors.deepOrange,
                ),
                _buildMetricChip(
                  context,
                  icon: Icons.terrain_rounded,
                  label: 'Altitude',
                  value: altString,
                  color: telemetry.isHighAltitudeRisk ? Colors.red : Colors.indigo,
                ),
                _buildMetricChip(
                  context,
                  icon: Icons.air_rounded,
                  label: 'Wind',
                  value: '${telemetry.windSpeedKmh} km/h',
                  color: Colors.blueGrey,
                ),
                _buildMetricChip(
                  context,
                  icon: Icons.wb_sunny_outlined,
                  label: 'UV Index',
                  value: '${telemetry.uvIndex}',
                  color: telemetry.isHighUvRisk ? Colors.purple : Colors.amber.shade800,
                ),
              ],
            ),

            // High Altitude / AMS Advisory Notice
            if (telemetry.isHighAltitudeRisk) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        telemetry.altitudeRiskAdvice,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Rapid Ascent Alert if any
            if (widget.ascentWarning != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade400),
                ),
                child: Row(
                  children: [
                    Icon(Icons.dangerous_rounded, color: Colors.red.shade900, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.ascentWarning!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                  color: color.withAlpha(200),
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
