import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../config/constants.dart';
import '../config/routes.dart';
import '../config/theme.dart';
import '../providers/app_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _logoScaleAnim;
  late Animation<double> _logoRotateAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _textScaleAnim;
  late Animation<double> _glowPulseAnim;

  final List<Star> _stars = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _generateStars();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _logoScaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _logoRotateAnim = Tween<double>(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeIn),
      ),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.9, curve: Curves.easeOutBack),
      ),
    );

    _textScaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.5, 0.9, curve: Curves.easeOut),
      ),
    );

    _glowPulseAnim = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Curves.easeInOut,
      ),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _mainController.reverse(from: 0.8);
        } else if (status == AnimationStatus.dismissed) {
          _mainController.forward(from: 0.0);
        }
      });

    _mainController.forward();

    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      }
    });
  }

  void _generateStars() {
    for (int i = 0; i < 25; i++) {
      _stars.add(
        Star(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          size: 1.5 + _random.nextDouble() * 3,
          opacity: 0.3 + _random.nextDouble() * 0.7,
          speed: 0.5 + _random.nextDouble() * 1.5,
        ),
      );
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0F0328),
              const Color(0xFF1A0A3E),
              const Color(0xFF2D1B69),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // ===== النجوم (بدون ظلال ضبابية باهظة لتجنب التهنيج) =====
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _mainController,
                builder: (context, _) {
                  final t = DateTime.now().millisecondsSinceEpoch / 1000;
                  final w = MediaQuery.of(context).size.width;
                  final h = MediaQuery.of(context).size.height;
                  return Stack(
                    children: [
                      for (final star in _stars)
                        Positioned(
                          left: star.x * w,
                          top: ((star.y + (t * star.speed * 0.02)) % 1.0) * h,
                          child: Container(
                            width: star.size,
                            height: star.size,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: star.opacity * 0.6),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),

            // ===== توهج الخلفية =====
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
                      AppTheme.accent.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.accentGold.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ===== المحتوى الرئيسي =====
            Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ===== الشعار (مخصص أو SVG) =====
                    Consumer<AppProvider>(
                      builder: (context, provider, _) {
                        final lp = provider.logoPath;
                        final hasCustomLogo = lp != null && File(lp).existsSync();

                        return RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: Listenable.merge(
                                [_logoScaleAnim, _logoRotateAnim, _glowPulseAnim]),
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _logoScaleAnim.value,
                                child: Transform.rotate(
                                  angle: _logoRotateAnim.value,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.accent.withValues(
                                              alpha: 0.10 * _glowPulseAnim.value),
                                          blurRadius:
                                              30 * _glowPulseAnim.value,
                                          spreadRadius:
                                              10 * _glowPulseAnim.value,
                                        ),
                                      ],
                                    ),
                                    child: hasCustomLogo
                                        ? ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(140),
                                            child: Image.file(
                                              File(lp),
                                              width: 140,
                                              height: 140,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : SvgPicture.asset(
                                            'assets/svg/logo.svg',
                                            width: 140,
                                            height: 140,
                                            fit: BoxFit.contain,
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 30),

                    // ===== النص الترحيبي =====
                    SlideTransition(
                      position: _slideAnim,
                      child: ScaleTransition(
                        scale: _textScaleAnim,
                        child: Column(
                          children: [
                            Text(
                              AppConstants.networkName,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 4,
                                shadows: [
                                  Shadow(
                                    color: AppTheme.accentGold.withValues(alpha: 0.3),
                                    blurRadius: 25,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'إنترنت · بث مباشر · ترفيه',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.accentGold.withValues(alpha: 0.7),
                                letterSpacing: 3,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 60),

                    // ===== مؤشر التحميل =====
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        children: [
                          Container(
                            width: 120,
                            height: 3,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                            child: AnimatedBuilder(
                              animation: _mainController,
                              builder: (context, _) {
                                return FractionallySizedBox(
                                  widthFactor: _mainController.value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2),
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppTheme.accentGold,
                                          AppTheme.accent,
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'جاري التحميل...',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted.withValues(alpha: 0.6),
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Star {
  final double x;
  final double y;
  final double size;
  final double opacity;
  final double speed;

  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.speed,
  });
}