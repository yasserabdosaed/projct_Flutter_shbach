import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../config/routes.dart';
import '../config/theme.dart';
import '../providers/app_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _logoTapCount = 0;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkBalance(context));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onLogoTap() {
    _logoTapCount++;
    if (_logoTapCount >= 5) {
      _logoTapCount = 0;
      Navigator.of(context).pushNamed(AppRoutes.adminLogin);
    }
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _logoTapCount = 0;
    });
  }

  void _checkBalance(BuildContext context) {
    final provider = context.read<AppProvider>();
    if (provider.isLowBalance && !provider.lowBalanceShown) {
      provider.resetLowBalanceWarning();
      _showLowBalanceDialog(context, provider.remainingMB);
    }
  }

  void _showLowBalanceDialog(BuildContext context, int remainingMB) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF162240),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppTheme.accentOrange, size: 28),
            ),
            const SizedBox(width: 12),
            const Text('رصيد منخفض', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('الرصيد المتبقي: ', style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 14)),
                Text('$remainingMB ميجابايت', style: const TextStyle(color: AppTheme.accentOrange, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            const Text('رصيدك على وشك النفاد. يرجى تجديد الاشتراك قريباً.', style: TextStyle(color: Color(0xFF78909C), fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('حسناً', style: TextStyle(color: AppTheme.accent)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 0.8,
            colors: [Color(0xFF0F1F3A), Color(0xFF060E1A)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: FadeTransition(
              opacity: _animationController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 16),
                  _buildStatusBar(context),
                  const SizedBox(height: 24),
                  const Text(
                    'الخدمات',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMenuGrid(context),
                  const SizedBox(height: 16),
                  _buildDemoBanner(context),
                  const SizedBox(height: 24),
                  _buildBottomLinks(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDemoBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentGold.withValues(alpha: 0.12),
            AppTheme.accent.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accentGold.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accentGold.withValues(alpha: 0.15),
            ),
            child: const Icon(
              Icons.preview_rounded,
              color: AppTheme.accentGold,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'وضع المعاينة التجريبية',
                  style: TextStyle(
                    color: AppTheme.accentGold,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'جرّب الخدمات الآن بدون اتصال بالشبكة',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.rest);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.accentGold,
              backgroundColor: AppTheme.accentGold.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'استعراض',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A237E).withValues(alpha: 0.4),
                const Color(0xFF0D47A1).withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // ===== الشعار (مخصص أو SVG) =====
              GestureDetector(
                onTap: _onLogoTap,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: _buildLogo(72, provider),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              // ===== الاسم =====
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          colors: [
                            Color(0xFFE3F2FD),
                            Color(0xFFB3D4FC),
                            Color(0xFF90CAF9),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds);
                      },
                      child: const Text(
                        'شبكة الحارث',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              color: Color(0xFF0D47A1),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                            Shadow(
                              color: Colors.black38,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'مرحباً بك!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // ===== أيقونة الإشعارات =====
              GestureDetector(
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.messages),
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: const Icon(Icons.notifications_rounded, color: Colors.white70, size: 24),
                    ),
                    if (provider.unreadCount > 0)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.error,
                          ),
                          child: Text(
                            '${provider.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBar(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        if (!provider.isConnected) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: provider.isLowBalance
                  ? [AppTheme.accentOrange.withValues(alpha: 0.12), Colors.transparent]
                  : [AppTheme.success.withValues(alpha: 0.08), Colors.transparent],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: provider.isLowBalance
                  ? AppTheme.accentOrange.withValues(alpha: 0.2)
                  : AppTheme.success.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: provider.isLowBalance
                      ? AppTheme.accentOrange.withValues(alpha: 0.15)
                      : AppTheme.success.withValues(alpha: 0.15),
                ),
                child: Icon(
                  provider.isLowBalance ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                  color: provider.isLowBalance ? AppTheme.accentOrange : AppTheme.success,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  provider.isLowBalance
                      ? 'الرصيد المتبقي: ${provider.remainingMB} ميجابايت'
                      : 'الرصيد: ${provider.remainingMB} ميجابايت',
                  style: TextStyle(
                    color: provider.isLowBalance ? AppTheme.accentOrange : AppTheme.success,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (provider.currentSpeed > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.speed_rounded,
                        size: 14,
                        color: provider.currentSpeed > 10 ? AppTheme.success : AppTheme.accentGold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${provider.currentSpeed.toStringAsFixed(0)} م.ث',
                        style: TextStyle(
                          fontSize: 11,
                          color: provider.currentSpeed > 10 ? AppTheme.success : AppTheme.accentGold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMenuItem(context, 'تسجيل الدخول', Icons.vpn_key_rounded, AppTheme.accent, AppRoutes.login)),
            const SizedBox(width: 12),
            Expanded(child: _buildMenuItem(context, 'منصة الاستراحة', Icons.hotel_rounded, AppTheme.accentGold, AppRoutes.rest)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildMenuItem(context, 'البث المباشر', Icons.live_tv_rounded, AppTheme.accentOrange, AppRoutes.live)),
            const SizedBox(width: 12),
            Expanded(child: _buildMenuItem(
              context,
              'عجلة الحظ',
              Icons.casino_rounded,
              AppTheme.accentGold,
              AppRoutes.spinWheel
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildLogo(double size, AppProvider provider) {
    final lp = provider.logoPath;
    final hasCustomLogo = lp != null && File(lp).existsSync();

    if (hasCustomLogo) {
      return Image.file(
        File(lp),
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    } else {
      return SvgPicture.asset(
        'assets/svg/logo.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }
  }

  Widget _buildMenuItem(BuildContext context, String title, IconData icon, Color color, String route) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.cardDark.withValues(alpha: 0.8),
            AppTheme.cardDark.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).pushNamed(route),
          borderRadius: BorderRadius.circular(20),
          splashColor: color.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.15)),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomLinks(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.cardDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _bottomLink(context, Icons.headset_mic_rounded, 'تواصل معنا', AppRoutes.contact),
          _bottomLink(context, Icons.lightbulb_outline, 'اقتراحات', AppRoutes.suggestions),
        ],
      ),
    );
  }

  Widget _bottomLink(BuildContext context, IconData icon, String label, String route) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(route),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppTheme.textMuted, size: 22),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}