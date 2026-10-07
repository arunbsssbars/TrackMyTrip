import 'package:flutter/material.dart';
import '../../models/convoy_peer_beacon.dart';
import '../../core/services/convoy_beacon_service.dart';

class ConvoyRadarSheet extends StatefulWidget {
  final double userLatitude;
  final double userLongitude;
  final List<ConvoyPeerBeacon> peers;
  final ValueChanged<bool>? onToggleUserSos;
  final bool initialUserSosState;

  const ConvoyRadarSheet({
    super.key,
    required this.userLatitude,
    required this.userLongitude,
    required this.peers,
    this.onToggleUserSos,
    this.initialUserSosState = false,
  });

  @override
  State<ConvoyRadarSheet> createState() => _ConvoyRadarSheetState();
}

class _ConvoyRadarSheetState extends State<ConvoyRadarSheet> {
  late bool _mySosActive;
  final ConvoyBeaconService _service = ConvoyBeaconService();

  @override
  void initState() {
    super.initState();
    _mySosActive = widget.initialUserSosState;
  }

  void _toggleMySos() {
    setState(() {
      _mySosActive = !_mySosActive;
    });
    widget.onToggleUserSos?.call(_mySosActive);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedPeers = _service.sortBeacons(
      peers: widget.peers,
      userLat: widget.userLatitude,
      userLon: widget.userLongitude,
    );
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
          // Drag Handle
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

          // Header Row
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.radar_rounded, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Convoy Proximity Radar',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${sortedPeers.length} active convoy beacons',
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
          const SizedBox(height: 10),

          // Broadcast SOS Full-Width Action Banner
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _toggleMySos,
              style: ElevatedButton.styleFrom(
                backgroundColor: _mySosActive ? Colors.red : theme.colorScheme.surfaceContainerHighest,
                foregroundColor: _mySosActive ? Colors.white : theme.colorScheme.onSurface,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: Icon(
                _mySosActive ? Icons.warning_amber_rounded : Icons.cell_tower_rounded,
                size: 18,
              ),
              label: Text(
                _mySosActive ? 'SOS ACTIVE (TAP TO CANCEL)' : 'Broadcast Convoy SOS',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Peer List
          Flexible(
            child: sortedPeers.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No convoy beacons nearby.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: sortedPeers.length,
                    itemBuilder: (context, index) {
                      final peer = sortedPeers[index];
                      final dist = _service.calculateDistanceKm(
                        userLat: widget.userLatitude,
                        userLon: widget.userLongitude,
                        peerLat: peer.latitude,
                        peerLon: peer.longitude,
                      );
                      final bearing = _service.calculateBearingDegrees(
                        userLat: widget.userLatitude,
                        userLon: widget.userLongitude,
                        peerLat: peer.latitude,
                        peerLon: peer.longitude,
                      );
                      final cardinal = _service.getCardinalDirection(bearing);

                      return Material(
                        color: Colors.transparent,
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: peer.isSosActive
                              ? Colors.red.shade50
                              : theme.colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: peer.isSosActive
                                  ? Colors.red.shade400
                                  : theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: peer.isSosActive
                                      ? Colors.red.shade100
                                      : theme.colorScheme.secondaryContainer,
                                  child: Icon(
                                    peer.isSosActive
                                        ? Icons.emergency_rounded
                                        : Icons.directions_car_rounded,
                                    size: 18,
                                    color: peer.isSosActive
                                        ? Colors.red.shade800
                                        : theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        peer.displayName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: peer.isSosActive
                                              ? Colors.red.shade900
                                              : theme.colorScheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${peer.vehiclePlateOrRole} • Bat: ${peer.batteryPercent}%',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (peer.isSosActive && peer.sosMessage != null)
                                        Text(
                                          'SOS: ${peer.sosMessage}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade700,
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
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${dist.toStringAsFixed(1)}km $cardinal',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
