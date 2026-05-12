import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_screen.dart';
import 'auth/login_screen.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../screens/manager/manager_home_screen.dart';
import '../screens/picker/picker_home_screen.dart';
import '../screens/super_admin/super_admin_home_screen.dart';
import '../services/notification_service.dart';
import '../utils/app_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;
  late Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)),
    );

    _ctrl.forward();

    // After 2.4s navigate to next screen
    Future.delayed(const Duration(milliseconds: 2400), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;

    // Check auth state first
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) {
      NotificationService.registerTokenSafe();
      final user = auth.user!;
      if (user.isSuperAdmin) {
        _go(const SuperAdminHomeScreen());
      } else if (user.isManager) {
        _go(const ManagerHomeScreen());
      } else {
        _go(const PickerHomeScreen());
      }
      return;
    }

    // Check if first launch
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_seen') ?? false;
    if (!mounted) return;

    _go(seen ? const LoginScreen() : const OnboardingScreen());
  }

  void _go(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF6C3CE1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Background decorative blobs
            Positioned(
              top: -80,
              right: -60,
              child: _Blob(size: 260, color: Colors.white.withValues(alpha: 0.06)),
            ),
            Positioned(
              bottom: -100,
              left: -80,
              child: _Blob(size: 320, color: Colors.white.withValues(alpha: 0.05)),
            ),
            Positioned(
              top: 160,
              left: -40,
              child: _Blob(size: 160, color: Colors.white.withValues(alpha: 0.04)),
            ),

            // Center content
