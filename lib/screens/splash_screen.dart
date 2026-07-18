import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import 'auth_screen.dart';
import 'map_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Initial fade-in animation for layout components
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();

    // 2. Slow repeating hover/float animation for the profile picture
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOutSine,
      ),
    );

    // 3. Progress bar filling animation over 3.5 seconds
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeInOutCubic,
      ),
    );
    _progressController.forward();

    _checkStatus();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _floatController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    // Wait for the premium loading progress and delay (4 seconds total)
    await Future.delayed(const Duration(milliseconds: 4000));
    if (!mounted) return;

    final supabaseService = Provider.of<SupabaseService>(context, listen: false);

    if (supabaseService.currentUser != null) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
      }
    } else {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            // Background Light Gradient
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white,
                      Color(0xFFF3F7FF),
                      Color(0xFFE6EFFF),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Top-right soft blue glow orb
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF60A5FA).withOpacity(0.35),
                      const Color(0xFF2563EB).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom-left soft violet-blue glow orb
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF3B82F6).withOpacity(0.2),
                      const Color(0xFF60A5FA).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Subtle Isometric Map Background
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.center,
                heightFactor: 0.9,
                widthFactor: 0.9,
                child: Opacity(
                  opacity: 0.08, // Very subtle, clean map lines as requested
                  child: Image.asset(
                    'assets/campus_isometric.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const SizedBox(),
                  ),
                ),
              ),
            ),

            // Soft blur overlay to blend building layout with the gradient background
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                child: const SizedBox(),
              ),
            ),

            // Main UI Layout
            Positioned.fill(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Spacer(flex: 2),

                        // Header Section: Logo + Title + Subtitle
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // App Logo Card
                            Container(
                              height: 100,
                              width: 100,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.map_outlined,
                                  size: 48,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            // App Title
                            Text(
                              "خريطة الجامعة",
                              style: GoogleFonts.cairo(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF2563EB),
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Subtitle
                            Text(
                              "اكتشف جامعتك بسهولة",
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF3B82F6),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),

                        const Spacer(flex: 2),

                        // Center Section: Profile Circle with Breathing/Floating Shadow Effect
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedBuilder(
                              animation: _floatAnimation,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(0, _floatAnimation.value),
                                  child: Container(
                                    width: 135,
                                    height: 135,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 3.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF2563EB).withOpacity(0.22),
                                          blurRadius: 24,
                                          spreadRadius: 4,
                                          offset: const Offset(0, 6),
                                        ),
                                        BoxShadow(
                                          color: const Color(0xFF60A5FA).withOpacity(0.18),
                                          blurRadius: 12,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        'assets/profile.jpg',
                                        fit: BoxFit.cover,
                                        alignment: Alignment.topCenter,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: const Color(0xFFE6EFFF),
                                          child: const Icon(
                                            Icons.person,
                                            size: 60,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 18),
                            // Animated breathing shadow on the ground
                            AnimatedBuilder(
                              animation: _floatAnimation,
                              builder: (context, child) {
                                double animValue = (_floatAnimation.value + 6) / 12; // 0.0 to 1.0
                                double shadowWidth = 90 - (18 * (1 - animValue)); // 72 to 90
                                double shadowOpacity = 0.06 + (0.06 * animValue);  // 0.06 to 0.12
                                return Container(
                                  width: shadowWidth,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.all(Radius.elliptical(shadowWidth, 8)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF2563EB).withOpacity(shadowOpacity),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),

                        const Spacer(flex: 2),

                        // Middle Informational Text
                        Text(
                          "مرحباً بك",
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "نرشدك في أرجاء جامعتك",
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4B5563),
                          ),
                        ),
                        Text(
                          "ونسهل الوصول لكل مكان",
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4B5563),
                          ),
                        ),

                        const Spacer(flex: 3),

                        // Loading Indicators
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedBuilder(
                              animation: _progressAnimation,
                              builder: (context, child) {
                                return Container(
                                  width: 160,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerRight, // RTL starting position
                                    child: Container(
                                      width: 160 * _progressAnimation.value,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF2563EB),
                                            Color(0xFF60A5FA),
                                          ],
                                          begin: Alignment.centerRight,
                                          end: Alignment.centerLeft,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "جاري التحميل...",
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF3B82F6),
                              ),
                            ),
                          ],
                        ),

                        const Spacer(flex: 4),

                        // Bottom Developer Glass Card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.65),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withOpacity(0.03),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Developer Details (Right side in RTL)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              "مبرمج المنصة",
                                              style: GoogleFonts.cairo(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF60A5FA),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF2563EB).withOpacity(0.07),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                "مرتضى فؤاد ✓",
                                                style: GoogleFonts.cairo(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: const Color(0xFF2563EB),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          "طالب علوم الحاسوب | ذكاء اصطناعي",
                                          style: GoogleFonts.cairo(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF1E3A8A),
                                          ),
                                        ),
                                        Text(
                                          "الجامعة التكنولوجية - بغداد",
                                          style: GoogleFonts.cairo(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Code Icon (Left side in RTL)
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withOpacity(0.07),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF2563EB).withOpacity(0.15),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.code_rounded,
                                        color: Color(0xFF2563EB),
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
