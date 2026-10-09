import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/admin_service.dart';
import 'auth_provider.dart';
import 'trip_provider.dart';

/// Evaluates if the current logged-in user or active session is the Super Admin (arunbsssbars@gmail.com)
final isSuperAdminProvider = Provider<bool>((ref) {
  final authUser = ref.watch(authNotifierProvider).valueOrNull;
  if (authUser != null && authUser.email.isNotEmpty) {
    if (AdminService.isSuperAdmin(authUser.email)) {
      return true;
    }
  }

  // Fallback check against persisted local session
  final storage = ref.watch(localStorageServiceProvider);
  final session = storage.getAuthSession();
  if (session != null && session.email.isNotEmpty) {
    return AdminService.isSuperAdmin(session.email);
  }

  return false;
});

/// Fetches real-time telemetry and free tier quota consumption for the Super Admin console
final adminMetricsProvider = FutureProvider.autoDispose<FreeTierQuotaMetrics>((ref) async {
  return await AdminService.fetchLiveQuotaStats();
});
