import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/theme/animations/galactic_background_unified.dart';
import '../controllers/auth_controller.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _bgController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _bgController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _fadeAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );

    _mainController.forward();
    _initApp();
  }

  Future<void> _initApp() async {
    // ⚡ Fast Initializer: Don't request permissions on boot (Slows down UI)
    // Most screens already check permissions when features are used.
    
    // We only wait for a minimum duration to show the branding animation
    final animationFuture = Future.delayed(const Duration(milliseconds: 1200));
    final auth = Get.find<AuthController>();

    // 🕵️ Parallel Execution: Animation + Auth Check
    await Future.wait([
      animationFuture,
      _waitForAuthSession(auth),
    ]);

    if (!mounted) return;

    // 🚀 High-Speed Routing
    if (auth.isLoggedIn) {
      Get.offAllNamed('/home');
    } else {
      Get.offAllNamed('/login');
    }
  }

  /// 🔐 Efficiently waits for the AuthController to finish its session check
  Future<void> _waitForAuthSession(AuthController auth) async {
    int timeout = 0;
    while (auth.isCheckingSession.value && timeout < 30) {
      await Future.delayed(const Duration(milliseconds: 100));
      timeout++;
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030303),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🌌 Galactic Background
          GalacticBackgroundUnified(animation: _bgController),

          // 💎 Centered Logo & Branding
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🔘 Premium Logo Container
                    _buildAnimatedLogo(),

                    const SizedBox(height: 40),

                    // 📝 Branding Text
                    Text(
                      "SMART CONTENT",
                      style: GoogleFonts.oswald(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "CREATOR 2026",
                      style: GoogleFonts.oswald(
                        fontSize: 20,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 12,
                        color: AppTheme.primary.withValues(alpha: 0.8),
                      ),
                    ),

                    const SizedBox(height: 100),

                    // ⏳ Luxury Progress
                    _buildLuxuryProgress(),
                  ],
                ),
              ),
            ),
          ),

          // 🛡️ Security Footnote
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Opacity(
                opacity: 0.3,
                child: Text(
                  "Smart Creator © 2026",
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppTheme.primary,
            AppTheme.accent.withValues(alpha: 0.2)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.4),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF0A0A0A),
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/images/styles/logoapp.jpeg',
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => Container(
              width: 120,
              height: 120,
              color: Colors.white10,
              child: const Icon(Icons.rocket_launch_rounded,
                  color: AppTheme.primary, size: 50),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLuxuryProgress() {
    return SizedBox(
      width: 150,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: const LinearProgressIndicator(
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              minHeight: 2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "جارٍ التحميل...",
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: Colors.white38,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

