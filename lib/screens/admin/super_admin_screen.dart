import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/admin_service.dart';
import '../../core/services/offline_sync_engine.dart';
import '../../core/services/security_service.dart';
import '../../core/services/secret_config_service.dart';
import '../../core/services/build_info_service.dart';
import '../../core/services/canary_health_service.dart';
import '../../core/services/cloudinary_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';

class SuperAdminScreen extends ConsumerStatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  ConsumerState<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends ConsumerState<SuperAdminScreen> {
  bool _isCleaningRooms = false;
  int? _lastCleanedCount;
  int _selectedSegment = 0;

  void _copyDiagnosticReport(FreeTierQuotaMetrics metrics) {
    final report = AdminService.generateSystemDiagnosticReport(metrics);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(report);
    Clipboard.setData(ClipboardData(text: jsonStr));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ System Diagnostic Report copied to clipboard.'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _runVaultDiagnostics() async {
    final securityService = SecurityService();
    final result = await securityService.performVaultHealthCheck();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_moon_rounded, color: Color(0xFF06B6D4)),
            SizedBox(width: 8),
            Text('Hardware Vault Probe', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${result['status']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Latency: ${result['latencyMs']} ms'),
            const SizedBox(height: 6),
            Text('Keystore Active: ${result['keystoreActive'] == true ? 'YES (Hardware Enforced)' : 'NO (Fallback)'}'),
            const SizedBox(height: 6),
            Text('Timestamp: ${result['timestamp']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _runCanaryProbe() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 14),
                Text('Probing live endpoints & canary services...'),
              ],
            ),
          ),
        ),
      ),
    );

    final result = await CanaryHealthService.runCanaryHealthProbe();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              result.isHealthy ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              color: result.isHealthy ? const Color(0xFF10B981) : Colors.red,
            ),
            const SizedBox(width: 8),
            Text('Canary Health: ${result.healthScore}%', style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verdict: ${result.shouldRollback ? "ROLLBACK RECOMMENDED" : "HEALTHY (PRODUCTION READY)"}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: result.shouldRollback ? Colors.red : const Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 12),
            ...result.serviceStatuses.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 6, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${e.key}: ${e.value}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Dismiss')),
        ],
      ),
    );
  }

  Future<void> _runCloudinaryProbe() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 14),
                Text('Probing Cloudinary endpoint & credentials...'),
              ],
            ),
          ),
        ),
      ),
    );

    final cloudinary = ref.read(cloudinaryServiceProvider);
    final result = await cloudinary.pingCloudinary();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              result['isHealthy'] == true ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              color: result['isHealthy'] == true ? const Color(0xFF10B981) : Colors.red,
            ),
            const SizedBox(width: 8),
            Text('Cloudinary: ${result['status']}', style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cloud Name: ${result['cloudName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Preset Active: ${result['presetConfigured'] ? "YES (Unsigned Mode)" : "NO"}'),
            const SizedBox(height: 6),
            Text('Latency: ${result['latencyMs']} ms'),
            const SizedBox(height: 6),
            Text('Message: ${result['message']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _runStaleRoomCleaner() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cleaning_services_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Clean Stale Rooms?'),
          ],
        ),
        content: const Text(
          'This will purge live sync rooms older than 30 days from Cloud Firestore to preserve your free-tier document and storage limits. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Purge Stale Rooms'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isCleaningRooms = true);
    try {
      final cleaned = await AdminService.cleanStaleRooms(daysOld: 30);
      if (mounted) {
        setState(() => _lastCleanedCount = cleaned);
        ref.invalidate(adminMetricsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Cleaned up $cleaned stale cloud room(s). Document quota preserved!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCleaningRooms = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final metricsAsync = ref.watch(adminMetricsProvider);
    final offlineEngine = ref.watch(offlineSyncEngineProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final contentPadding = screenWidth > 800
        ? (screenWidth - 700) / 2
        : (screenWidth < 340 ? 10.0 : 16.0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_rounded, color: Color(0xFF6366F1), size: 22),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Super Admin Console',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh Metrics',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(adminMetricsProvider),
          ),
        ],
      ),
      body: metricsAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Polling Firebase Free-Tier Telemetry...',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text('Failed to query cloud telemetry: $err', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(adminMetricsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (metrics) => SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: EdgeInsets.symmetric(horizontal: contentPadding, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Executive Authority Ribbon (Modern Slate / Indigo)
              _buildAuthorityRibbon(isDark, metrics),
              const SizedBox(height: 12),

              // Executive Horizontal KPI Bar
              _buildExecutiveKpiBar(isDark, metrics),
              const SizedBox(height: 14),

              // 3-Segment Navigation Switcher
              _buildSegmentSwitcher(isDark),
              const SizedBox(height: 16),

              // Segment Views
              if (_selectedSegment == 0) ...[
                // Segment 0: Free Tier Quotas & Cloud Preserver
                _buildSectionHeader('Firebase Free-Tier Limits (Spark Plan)', Icons.cloud_done_rounded, const Color(0xFF3B82F6)),
                const SizedBox(height: 10),
                _buildFirestoreCard(isDark, metrics),
                const SizedBox(height: 12),
                _buildRtdbCard(isDark, metrics),
                const SizedBox(height: 12),
                _buildCloudinaryStorageCard(isDark, metrics),
                const SizedBox(height: 12),
                _buildAuthAndSecurityRow(isDark, metrics),
                const SizedBox(height: 18),
                _buildSectionHeader('Cloud Room Quota Preserver', Icons.auto_delete_rounded, const Color(0xFFF97316)),
                const SizedBox(height: 10),
                _buildRoomMaintenanceCard(isDark, metrics),
              ] else if (_selectedSegment == 1) ...[
                // Segment 1: Connectivity & Latency Diagnostics
                _buildSectionHeader('Live Infrastructure & Diagnostics', Icons.speed_rounded, const Color(0xFF10B981)),
                const SizedBox(height: 10),
                _buildLatencyCard(isDark, metrics, offlineEngine),
                const SizedBox(height: 14),
                _buildCanaryQuickProbeCard(isDark),
              ] else ...[
                // Segment 2: DevOps CI/CD & DevSecOps Posture
                _buildSectionHeader('DevOps CI/CD & Pipeline Status', Icons.integration_instructions_rounded, const Color(0xFF8B5CF6)),
                const SizedBox(height: 10),
                _buildDevOpsPipelineCard(isDark),
                const SizedBox(height: 14),
                _buildSectionHeader('DevSecOps & Secrets Vault Posture', Icons.security_rounded, const Color(0xFF06B6D4)),
                const SizedBox(height: 10),
                _buildSecurityPostureCard(isDark),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.data_object_rounded, size: 18),
                  label: const Text('Export System Diagnostic Report (JSON)', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _copyDiagnosticReport(metrics),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthorityRibbon(bool isDark, FreeTierQuotaMetrics metrics) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [Colors.white, const Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withAlpha(isDark ? 40 : 25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_rounded, color: Color(0xFF6366F1), size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'SUPER ADMIN',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.6,
                        color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('ACTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  AdminService.superAdminEmail,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'Project: trackmytrip-sync-2026 • Region: asia-south1',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutiveKpiBar(bool isDark, FreeTierQuotaMetrics metrics) {
    final readsPct = metrics.firestoreReadsPercent;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 340;
        final chipFirestore = _buildKpiChip(
          icon: Icons.local_fire_department_rounded,
          iconColor: const Color(0xFFF97316),
          label: 'Firestore',
          value: '${readsPct.toStringAsFixed(0)}%',
          sub: '${metrics.firestoreEstimatedReads} reads',
          isDark: isDark,
        );
        final chipRtdb = _buildKpiChip(
          icon: Icons.bolt_rounded,
          iconColor: const Color(0xFF38BDF8),
          label: 'RTDB',
          value: '${metrics.rtdbActiveConnections}',
          sub: '${metrics.rtdbStorageMb.toStringAsFixed(1)} MB',
          isDark: isDark,
        );
        final chipStorage = _buildKpiChip(
          icon: Icons.cloud_done_rounded,
          iconColor: const Color(0xFF0284C7),
          label: metrics.isCloudinaryActive ? 'Cloudinary' : 'Storage',
          value: metrics.isCloudinaryActive
              ? '${metrics.cloudinaryStorageMb.toStringAsFixed(1)} MB'
              : '${metrics.storageUsedMb.toStringAsFixed(1)} MB',
          sub: metrics.isCloudinaryActive ? '25 GB cap' : '5 GB free',
          isDark: isDark,
        );
        final chipLatency = _buildKpiChip(
          icon: Icons.speed_rounded,
          iconColor: const Color(0xFF10B981),
          label: 'Latency',
          value: metrics.firestoreLatencyMs != null ? '${metrics.firestoreLatencyMs} ms' : 'Online',
          sub: 'Spark Plan',
          isDark: isDark,
        );

        if (isNarrow) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: chipFirestore),
                    Container(width: 1, height: 34, color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                    Expanded(child: chipRtdb),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(height: 1, color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: chipStorage),
                    Container(width: 1, height: 34, color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                    Expanded(child: chipLatency),
                  ],
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(child: chipFirestore),
              Container(width: 1, height: 34, color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              Expanded(child: chipRtdb),
              Container(width: 1, height: 34, color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              Expanded(child: chipStorage),
              Container(width: 1, height: 34, color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              Expanded(child: chipLatency),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKpiChip({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String sub,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: iconColor),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            sub,
            style: const TextStyle(fontSize: 9, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentSwitcher(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 340;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              _buildSegmentButton(0, isNarrow ? 'Quotas' : 'Quotas & Cloud', Icons.cloud_done_rounded, isDark),
              _buildSegmentButton(1, 'Diagnostics', Icons.speed_rounded, isDark),
              _buildSegmentButton(2, isNarrow ? 'DevOps' : 'DevOps & Security', Icons.security_rounded, isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSegmentButton(int index, String label, IconData icon, bool isDark) {
    final isSelected = _selectedSegment == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedSegment = index);
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? const Color(0xFF334155) : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 40 : 15),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected
                    ? (isDark ? Colors.white : AppTheme.primary)
                    : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? (isDark ? Colors.white : AppTheme.primary)
                        : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCanaryQuickProbeCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.health_and_safety_rounded, color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Canary Probes & Health Checks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Synthetics, Hardware Vault & Zero-Latency Ping', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _runCanaryProbe,
                  icon: const Icon(Icons.radar_rounded, size: 16),
                  label: const Text('Probe Canary', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _runVaultDiagnostics,
                  icon: const Icon(Icons.shield_moon_rounded, size: 16),
                  label: const Text('Probe Vault', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: -0.2),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFirestoreCard(bool isDark, FreeTierQuotaMetrics metrics) {
    final readsPct = metrics.firestoreReadsPercent;
    final writesPct = metrics.firestoreWritesPercent;
    final storagePct = metrics.firestoreStoragePercent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.local_fire_department_rounded, color: Color(0xFFF97316), size: 20),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Cloud Firestore',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (readsPct > 80 ? Colors.red : const Color(0xFF10B981)).withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  readsPct > 80 ? 'QUOTA WARNING' : 'HEALTHY • SAFE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: readsPct > 80 ? Colors.red : const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Daily Reads
          _buildQuotaGauge(
            label: 'Daily Reads',
            current: metrics.firestoreEstimatedReads.toDouble(),
            limit: FreeTierQuotaMetrics.firestoreMaxDailyReads.toDouble(),
            unit: 'reads',
            percent: readsPct,
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // Daily Writes
          _buildQuotaGauge(
            label: 'Daily Writes',
            current: metrics.firestoreEstimatedWrites.toDouble(),
            limit: FreeTierQuotaMetrics.firestoreMaxDailyWrites.toDouble(),
            unit: 'writes',
            percent: writesPct,
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // Total Storage
          _buildQuotaGauge(
            label: 'Total Document Storage',
            current: metrics.firestoreStorageMb,
            limit: FreeTierQuotaMetrics.firestoreMaxStorageMb,
            unit: 'MB',
            percent: storagePct,
            isDark: isDark,
          ),
          const SizedBox(height: 14),

          // Collection Breakdown Pills
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildMetricPill('Trips', '${metrics.firestoreTripsCount}', isDark),
              _buildMetricPill('Rooms', '${metrics.firestoreRoomsCount}', isDark),
              _buildMetricPill('Users', '${metrics.firestoreUsersCount}', isDark),
              _buildMetricPill('Tombstones', '${metrics.firestoreTombstonesCount}', isDark),
              _buildMetricPill('Invites', '${metrics.firestoreInvitationsCount}', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRtdbCard(bool isDark, FreeTierQuotaMetrics metrics) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt_rounded, color: Color(0xFFEAB308), size: 20),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Firebase Realtime Database',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildQuotaGauge(
            label: 'Simultaneous Connections',
            current: metrics.rtdbActiveConnections.toDouble(),
            limit: FreeTierQuotaMetrics.rtdbMaxSimultaneousConnections.toDouble(),
            unit: 'conn',
            percent: metrics.rtdbConnectionsPercent,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildQuotaGauge(
            label: 'Realtime Storage Footprint',
            current: metrics.rtdbStorageMb,
            limit: FreeTierQuotaMetrics.rtdbMaxStorageMb,
            unit: 'MB',
            percent: (metrics.rtdbStorageMb / FreeTierQuotaMetrics.rtdbMaxStorageMb * 100).clamp(0.0, 100.0),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildCloudinaryStorageCard(bool isDark, FreeTierQuotaMetrics metrics) {
    final storagePct = metrics.cloudinaryStoragePercent;
    final isWarn = metrics.isCloudinaryWarning;
    final isCrit = metrics.isCloudinaryCritical;
    final statusColor = isCrit
        ? Colors.red
        : (isWarn ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

    final remainingMb = (metrics.cloudinaryMaxStorageMb - metrics.cloudinaryStorageMb).clamp(0.0, metrics.cloudinaryMaxStorageMb);
    final remainingPhotosEstimate = (remainingMb / 0.3).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCrit
              ? Colors.red.withAlpha(120)
              : (isWarn ? const Color(0xFFF59E0B).withAlpha(120) : (isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF0284C7), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'Cloudinary Media Storage',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            metrics.isCloudinaryActive ? '25 GB CAP' : 'INACTIVE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cloud: ${metrics.cloudinaryCloudName} • Preset: Active • FHD Opt: ON',
                      style: TextStyle(fontSize: 10.5, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: _runCloudinaryProbe,
                icon: const Icon(Icons.radar_rounded, size: 13),
                label: const Text('Ping', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Storage Linear Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (storagePct / 100.0).clamp(0.005, 1.0),
              minHeight: 8,
              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 8),

          // Storage Telemetry Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 280;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${metrics.cloudinaryStorageMb.toStringAsFixed(1)} MB / 25,600 MB',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${storagePct.toStringAsFixed(1)}% Used (25 GB Cap)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: statusColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${metrics.cloudinaryStorageMb.toStringAsFixed(1)} MB / 25,600 MB',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${storagePct.toStringAsFixed(1)}% Used (25 GB Cap)',
                      textAlign: TextAlign.end,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: statusColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),

          // Metric Badges Row
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Photos Stored', style: TextStyle(fontSize: 9.5, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        '${metrics.cloudinaryEstimatedPhotoCount}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 24, color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Remaining Cap', style: TextStyle(fontSize: 9.5, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        '~$remainingPhotosEstimate photos',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF10B981)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 24, color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Optimization', style: TextStyle(fontSize: 9.5, color: Colors.grey)),
                      SizedBox(height: 2),
                      Text(
                        '1080p (75%)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF0284C7)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (isWarn) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: (isCrit ? Colors.red : const Color(0xFFF59E0B)).withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (isCrit ? Colors.red : const Color(0xFFF59E0B)).withAlpha(60)),
              ),
              child: Row(
                children: [
                  Icon(
                    isCrit ? Icons.warning_rounded : Icons.info_outline_rounded,
                    color: isCrit ? Colors.red : const Color(0xFFF59E0B),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCrit
                          ? 'CRITICAL: 25 GB quota near 100%. Uploads will pause safely in local SQLite.'
                          : 'WARNING: Storage is above 80% (20 GB). Free tier remains active.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCrit ? Colors.red : const Color(0xFFD97706),
                      ),
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

  Widget _buildAuthAndSecurityRow(bool isDark, FreeTierQuotaMetrics metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 340;
        final authCard = Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.people_alt_rounded, color: Color(0xFF8B5CF6), size: 18),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Authentication',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${metrics.authTotalUsers} / 50K',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              const Text(
                'Free Quota: 50K MAUs',
                style: TextStyle(fontSize: 10.5, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );

        final vaultCard = Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_moon_rounded, color: Color(0xFF10B981), size: 18),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Hardware Vault',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'AES-256 GCM',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                'Keystore: Enforced',
                style: TextStyle(fontSize: 10.5, color: Color(0xFF10B981)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );

        if (isNarrow) {
          return Column(
            children: [
              authCard,
              const SizedBox(height: 10),
              vaultCard,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: authCard),
            const SizedBox(width: 10),
            Expanded(child: vaultCard),
          ],
        );
      },
    );
  }

  Widget _buildLatencyCard(bool isDark, FreeTierQuotaMetrics metrics, OfflineSyncEngine engine) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: _buildLatencyItem(
                  'Firestore RTT',
                  metrics.firestoreLatencyMs != null ? '${metrics.firestoreLatencyMs} ms' : 'Offline',
                  metrics.firestoreLatencyMs != null && metrics.firestoreLatencyMs! < 300
                      ? const Color(0xFF10B981)
                      : Colors.amber,
                ),
              ),
              Container(height: 30, width: 1, color: isDark ? Colors.white12 : Colors.black12),
              Expanded(
                child: _buildLatencyItem(
                  'Gateway RTT',
                  metrics.rtdbLatencyMs != null ? '${metrics.rtdbLatencyMs} ms' : 'Healthy',
                  const Color(0xFF10B981),
                ),
              ),
              Container(height: 30, width: 1, color: isDark ? Colors.white12 : Colors.black12),
              Expanded(
                child: _buildLatencyItem(
                  'Outbox Queue',
                  '${engine.pendingCount} pending',
                  engine.pendingCount == 0 ? const Color(0xFF10B981) : Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLatencyItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: Colors.grey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildRoomMaintenanceCard(bool isDark, FreeTierQuotaMetrics metrics) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Active Live Rooms: ${metrics.firestoreRoomsCount}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_lastCleanedCount != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Last cleaned: $_lastCleanedCount',
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Purge stale cloud sharing rooms older than 30 days to free document quota. Active trip packages remain intact on participants’ local devices.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFF97316)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isCleaningRooms ? null : _runStaleRoomCleaner,
            icon: _isCleaningRooms
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cleaning_services_rounded, size: 16, color: Color(0xFFF97316)),
            label: Text(
              _isCleaningRooms ? 'Scanning...' : 'Clean Stale Rooms (> 30 Days)',
              style: const TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold, fontSize: 11.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaGauge({
    required String label,
    required double current,
    required double limit,
    required String unit,
    required double percent,
    required bool isDark,
  }) {
    final progressColor = percent > 85
        ? Colors.red
        : (percent > 65 ? Colors.orange : const Color(0xFF10B981));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 280;
            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${current.toStringAsFixed(0)} / ${limit.toStringAsFixed(0)} $unit (${percent.toStringAsFixed(1)}%)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: progressColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${current.toStringAsFixed(0)} / ${limit.toStringAsFixed(0)} $unit (${percent.toStringAsFixed(1)}%)',
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: progressColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (percent / 100.0).clamp(0.005, 1.0),
            minHeight: 6,
            backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricPill(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(12) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDevOpsPipelineCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFF8B5CF6), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GitHub Actions CI/CD Infrastructure',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      'Build: ${BuildInfoService.formattedVersion} • ${AdminService.runtimeEnvironment}',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPipelineStatusBadge('Commit', BuildInfoService.commitHash.length > 7 ? BuildInfoService.commitHash.substring(0, 7) : BuildInfoService.commitHash, Colors.indigo, isDark),
              _buildPipelineStatusBadge('CI Quality Gate', 'Automated', Colors.green, isDark),
              _buildPipelineStatusBadge('Android APK Build', 'Automated', Colors.blue, isDark),
              _buildPipelineStatusBadge('iOS Unsigned IPA', 'Automated', Colors.orange, isDark),
              _buildPipelineStatusBadge('DevSecOps Scanner', 'Automated', Colors.purple, isDark),
              _buildPipelineStatusBadge('Firebase IaC Rules', 'Automated', Colors.teal, isDark),
              _buildPipelineStatusBadge('LCOV Coverage', 'Enforced', Colors.cyan, isDark),
              _buildPipelineStatusBadge('Bundle Budget', '< 50 MB', Colors.amber, isDark),
              _buildPipelineStatusBadge('CI Concurrency', 'Auto-Cancel', Colors.deepPurple, isDark),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(AdminService.ciActionsUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                  label: const Text('Actions Pipeline', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(AdminService.gitReleasesUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Release Downloads', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _runCanaryProbe,
              icon: const Icon(Icons.health_and_safety_rounded, size: 16),
              label: const Text('Execute Live Canary Health Probe', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineStatusBadge(String name, String status, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 30 : 20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            '$name: $status',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityPostureCard(bool isDark) {
    final securityAudit = AdminService.generateSecurityAuditSummary();
    final secrets = securityAudit['secretsAudit'] as Map<String, dynamic>;
    final score = securityAudit['securityScore'] as int;
    final grade = securityAudit['scoreGrade'] as String;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.verified_user_rounded, color: Color(0xFF06B6D4), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DevSecOps Health: $score/100',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      grade,
                      style: TextStyle(
                        fontSize: 12,
                        color: score >= 90 ? const Color(0xFF10B981) : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: _runVaultDiagnostics,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Probe Vault', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          const Text('Masked Environment Secrets Telemetry:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildSecretRow(
            'Google Maps API Key',
            secrets['googleMapsApiKeyMasked'] as String,
            secrets['googleMapsConfigured'] == true,
            isDark,
          ),
          const SizedBox(height: 6),
          _buildSecretRow(
            'Firebase App ID',
            secrets['firebaseAppIdMasked'] as String,
            secrets['firebaseAppIdConfigured'] == true,
            isDark,
          ),
          const SizedBox(height: 6),
          _buildSecretRow(
            'Vault Salt & Pepper',
            SecretConfigService.maskSecret(SecretConfigService.vaultPepper),
            true,
            isDark,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPipelineStatusBadge('Hardware Keystore', 'AES-256 GCM', Colors.cyan, isDark),
              _buildPipelineStatusBadge('OWASP MASVS', 'FLAG_SECURE', Colors.teal, isDark),
              _buildPipelineStatusBadge('Location Privacy', '250m Fuzzing', Colors.indigo, isDark),
              _buildPipelineStatusBadge('Forensic Wipe', 'Armed', const Color(0xFF10B981), isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecretRow(String label, String maskedValue, bool isConfigured, bool isDark) {
    return Row(
      children: [
        Icon(
          isConfigured ? Icons.check_circle_rounded : Icons.info_outline_rounded,
          size: 14,
          color: isConfigured ? const Color(0xFF10B981) : Colors.grey,
        ),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontSize: 12)),
        Expanded(
          child: Text(
            maskedValue,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              color: isConfigured ? (isDark ? Colors.cyanAccent : Colors.cyan.shade800) : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}
