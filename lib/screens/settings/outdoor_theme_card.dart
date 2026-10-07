import 'package:flutter/material.dart';
import '../../core/services/outdoor_theme_service.dart';
import '../../models/outdoor_theme_profile.dart';

class OutdoorThemeCard extends StatefulWidget {
  final OutdoorThemeProfile? initialProfile;
  final ValueChanged<OutdoorThemeProfile>? onProfileChanged;

  const OutdoorThemeCard({
    super.key,
    this.initialProfile,
    this.onProfileChanged,
  });

  @override
  State<OutdoorThemeCard> createState() => _OutdoorThemeCardState();
}

class _OutdoorThemeCardState extends State<OutdoorThemeCard> {
  late OutdoorThemeProfile _current;
  final OutdoorThemeService _service = OutdoorThemeService();

  @override
  void initState() {
    super.initState();
    _current = widget.initialProfile ?? _service.currentProfile;
  }

  void _updateMode(OutdoorDisplayMode mode) {
    setState(() {
      _current = _current.copyWith(mode: mode);
    });
    _service.updateProfile(_current);
    widget.onProfileChanged?.call(_current);
  }

  void _toggleAmoledBlack(bool value) {
    setState(() {
      _current = _current.copyWith(amoledPureBlack: value);
    });
    _service.updateProfile(_current);
    widget.onProfileChanged?.call(_current);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final adaptedScheme = _service.getAdaptedColorScheme(theme.colorScheme);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(80)),
      ),
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
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  child: Icon(Icons.wb_sunny_rounded, color: theme.colorScheme.secondary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Outdoor Glare & Night Theme',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Optimized for desert sun & night drives',
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
            const SizedBox(height: 16),

            // Mode Selector Grid/Wrap
            Text(
              'Display Profile',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            ...OutdoorDisplayMode.values.map((mode) {
              final isSelected = _current.mode == mode;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant.withAlpha(60),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  color: isSelected ? theme.colorScheme.primaryContainer.withAlpha(50) : null,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _updateMode(mode),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _service.getModeTitle(mode),
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _service.getModeDescription(mode),
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 8),

            // AMOLED Pure Black Toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _current.amoledPureBlack,
              onChanged: _toggleAmoledBlack,
              title: const Text('AMOLED Pure Black (#000000)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text('Turns off OLED pixels to maximize battery & pitch-black comfort', style: TextStyle(fontSize: 11)),
            ),

            const SizedBox(height: 12),

            // Live Readability Preview Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: adaptedScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: adaptedScheme.outline.withAlpha(120), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Text(
                        'FIELD READABILITY PREVIEW',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.bold,
                          color: adaptedScheme.primary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: adaptedScheme.primary.withAlpha(40),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _current.mode == OutdoorDisplayMode.sunlightGlareHighContrast
                              ? 'SUNLIGHT SHIELD'
                              : _current.mode.name.toUpperCase(),
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: adaptedScheme.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Speed: 84 km/h • Alt: 3,420m',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: adaptedScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Convoy Beacon: Active • SOS Link: Green',
                    style: TextStyle(
                      fontSize: 11,
                      color: adaptedScheme.onSurface.withAlpha(200),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
