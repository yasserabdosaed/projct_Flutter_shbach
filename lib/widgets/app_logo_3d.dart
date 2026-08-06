import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/theme.dart';

class AppLogo3D extends StatelessWidget {
  final double size;
  final bool showName;
  final bool glowing;

  const AppLogo3D({
    super.key,
    this.size = 120,
    this.showName = false,
    this.glowing = true,
  });

  @override
  Widget build(BuildContext context) {
    final logoSize = size * 0.55;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow
              if (glowing)
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.15),
                        blurRadius: size * 0.4,
                        spreadRadius: size * 0.1,
                      ),
                    ],
                  ),
                ),
              // 3D depth ring - back layer
              Transform(
                transform: Matrix4.translationValues(0.0, size * 0.04, 0.0),
                child: Container(
                  width: size * 0.92,
                  height: size * 0.92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.accent.withValues(alpha: 0.5),
                        AppTheme.accentGold.withValues(alpha: 0.3),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: size * 0.12,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                ),
              ),
              // Main circular body with gradient
              Container(
                width: size * 0.92,
                height: size * 0.92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF190741),
                      Color(0xFF2A1A5E),
                      Color(0xFF0F0328),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.3),
                      blurRadius: size * 0.2,
                      spreadRadius: size * 0.05,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: size * 0.15,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Center icon - use SvgPicture with logo.png
                      SvgPicture.asset(
                        'assets/svg/logo.svg',
                        width: logoSize,
                        height: logoSize,
                        fit: BoxFit.contain,
                      ),
                      // Glossy top highlight
                      Positioned(
                        top: 0,
                        left: size * 0.1,
                        right: size * 0.1,
                        child: Container(
                          height: size * 0.35,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.15),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Edge shadow - inner
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: size * 0.2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.3),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Outer ring accent
              Positioned.fill(
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showName) ...[
          const SizedBox(height: 12),
          // 3D Text
          Text(
            'شبكة الحارث',
            style: TextStyle(
              fontSize: size * 0.18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
              shadows: [
                Shadow(
                  color: AppTheme.accent.withValues(alpha: 0.5),
                  blurRadius: 20,
                ),
                Shadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 6),
                ),
                Shadow(
                  color: AppTheme.accentGold.withValues(alpha: 0.2),
                  blurRadius: 30,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
