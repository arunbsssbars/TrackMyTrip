import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../main_scaffold.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> with WidgetsBindingObserver {
  bool _isChecking = false;
  bool _isResending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  Timer? _periodicCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Periodically poll every 3 seconds to see if the user clicked the link in their email
    _periodicCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkVerificationStatus(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User switched back from email client or browser; check status immediately
      _checkVerificationStatus(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    _periodicCheckTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendCooldown = 0);
      } else {
        if (mounted) setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _checkVerificationStatus({bool silent = false}) async {
    if (_isChecking && !silent) return;
    if (!silent) setState(() => _isChecking = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        final refreshedUser = FirebaseAuth.instance.currentUser;
        if (refreshedUser != null && refreshedUser.emailVerified) {
          _periodicCheckTimer?.cancel();
          if (mounted) {
            // Re-initialize session in AuthNotifier
            ref.read(authNotifierProvider.notifier).refreshSession();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ Email verified successfully! Welcome to Track My Trip.'),
                backgroundColor: Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainScaffold()),
              (route) => false,
            );
          }
          return;
        }
      } else {
        // Fallback for offline or test mode without active Firebase connection
        final session = ref.read(authServiceProvider).currentSession;
        if (session != null) {
          _periodicCheckTimer?.cancel();
          if (mounted) {
            ref.read(authNotifierProvider.notifier).refreshSession();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainScaffold()),
              (route) => false,
            );
          }
          return;
        }
      }

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email not verified yet. Please check your inbox or spam folder and tap the link.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification check failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (!silent && mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _resendVerification() async {
    if (_resendCooldown > 0 || _isResending) return;
    setState(() => _isResending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await user.sendEmailVerification(
            ActionCodeSettings(
              url: 'https://trackmytrip-sync-2026.web.app/verify-email?appName=TrackMyTrip',
              handleCodeInApp: false,
              androidPackageName: 'com.trackmytrip.app',
              androidInstallApp: true,
              androidMinimumVersion: '1',
              iOSBundleId: 'com.trackmytrip.app',
            ),
          );
        } catch (_) {
          await user.sendEmailVerification();
        }
        _startCooldown();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Verification email sent to ${widget.email}'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend email: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _handleLogout() async {
    _periodicCheckTimer?.cancel();
    await ref.read(authNotifierProvider.notifier).logout();
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing Mail Verification Badge
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(isDark ? 30 : 20),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primary.withAlpha(80), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withAlpha(isDark ? 40 : 25),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.mark_email_unread_rounded,
                      size: 48,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                const Text(
                  'Verify Your Email',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                Text(
                  'We sent an authentication link to:',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceMutedDark : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.email,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Please open your inbox, click the verification link, then tap "I\'ve Verified My Email" below.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // Button: Check Status
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : () => _checkVerificationStatus(silent: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    child: _isChecking
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  "I've Verified My Email",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 14),

                // Button: Resend Email
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: (_resendCooldown > 0 || _isResending) ? null : _resendVerification,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1)),
                    ),
                    child: _isResending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _resendCooldown > 0
                                ? 'Resend available in ${_resendCooldown}s'
                                : 'Resend Verification Email',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
