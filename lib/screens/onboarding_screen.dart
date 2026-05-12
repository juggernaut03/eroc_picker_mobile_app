import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth/login_screen.dart';

// ─── Page data ────────────────────────────────────────────────────────────────
class _OnboardData {
  final String title, subtitle, assetPath;
  final List<Color> gradientColors;
  const _OnboardData({
    required this.title,
    required this.subtitle,
    required this.assetPath,
    required this.gradientColors,
  });
}

const _pages = [
  _OnboardData(
    title: 'Smart Order Picking',
    subtitle: 'Get your assigned orders instantly. See item details, quantities and store location — all in one tap.',
    assetPath: 'assets/images/screen1.webp',
    gradientColors: [Color(0xFF6C3CE1), Color(0xFF8B5CF6)],
  ),
  _OnboardData(
    title: 'Track Every Item',
    subtitle: 'Mark items as picked, unavailable, expired or damaged. Add remarks and track your progress in real time.',
    assetPath: 'assets/images/screen2.webp',
    gradientColors: [Color(0xFF1565C0), Color(0xFF2563EB)],
  ),
  _OnboardData(
    title: 'Complete with Confidence',
    subtitle: 'Your manager sees every update live. Complete orders seamlessly and keep the warehouse moving efficiently.',
    assetPath: 'assets/images/screen3.webp',
    gradientColors: [Color(0xFF16A34A), Color(0xFF22C55E)],
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _current = 0;

  Future<void> _done() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _next() {
    if (_current < _pages.length - 1) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      _done();
    }
  }

  void _prev() {
    _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_current];
    final isLast = _current == _pages.length - 1;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Gradient top area ──────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            height: size.height * 0.48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: page.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
            ),
          ),

          // Decorative circles
          Positioned(
            top: -70,
            right: -50,
            child: _Circle(size: 220, opacity: 0.07),
          ),
          Positioned(
            top: 50,
            left: -60,
            child: _Circle(size: 170, opacity: 0.05),
          ),

          // ── Main content ──────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Skip
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 6, 20, 0),
                    child: TextButton(
                      onPressed: _done,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                // Pages
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _current = i),
                    itemBuilder: (_, i) => _PageContent(data: _pages[i]),
                  ),
                ),

                // ── Bottom controls ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
                  child: Column(
                    children: [
                      // Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (i) {
                          final active = i == _current;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 28 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active
                                  ? page.gradientColors[0]
                                  : page.gradientColors[0].withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 28),

                      // Buttons
