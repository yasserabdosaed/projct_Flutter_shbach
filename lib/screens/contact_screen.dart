import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:provider/provider.dart';
import '../config/constants.dart';
import '../config/theme.dart';
import '../providers/app_provider.dart';
import '../widgets/app_logo_3d.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('تواصل معنا', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.accent),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 0.8,
            colors: [Color(0xFF190741), Color(0xFF0F0328)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // ===== الشعار (مخصص أو AppLogo3D) =====
                Consumer<AppProvider>(
                  builder: (context, provider, _) {
                    final lp = provider.logoPath;
                    final custom = lp != null && File(lp).existsSync();
                    return Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppTheme.accent, AppTheme.accentGold],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accent.withValues(alpha: 0.3),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: custom
                            ? Image.file(File(lp), width: 100, height: 100, fit: BoxFit.cover)
                            : const AppLogo3D(size: 100, glowing: false),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  'شبكة الحارث',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'إنترنت · بث مباشر · ترفيه',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.accent.withValues(alpha: 0.7),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 32),
                _card(
                  context,
                  Icons.chat_rounded,
                  'واتساب',
                  'تواصل معنا مباشرة',
                  const Color(0xFF25D366),
                  () => _url('https://wa.me/${p.whatsapp}'),
                ),
                const SizedBox(height: 12),
                _card(
                  context,
                  Icons.group_add_rounded,
                  'انضم لمجموعتنا',
                  'مجموعة واتساب',
                  const Color(0xFF25D366),
                  () {
                    final link = p.whatsappGroup.isNotEmpty && p.whatsappGroup != 'https://chat.whatsapp.com/'
                        ? p.whatsappGroup
                        : 'https://wa.me/${p.whatsapp}';
                    _url(link);
                  },
                ),
                const SizedBox(height: 12),
                if (p.phone.isNotEmpty && p.phone != p.whatsapp)
                  _card(
                    context,
                    Icons.phone_rounded,
                    'اتصال هاتفي',
                    'رقم الهاتف',
                    AppTheme.accent,
                    () => _url('tel:${p.phone}'),
                  ),
                if (p.phone.isNotEmpty && p.phone != p.whatsapp) const SizedBox(height: 12),
                _card(
                  context,
                  Icons.lightbulb_rounded,
                  'اقتراحات',
                  'شاركنا باقتراحاتك',
                  AppTheme.accentGold,
                  () => _suggestionDialog(context),
                ),
                const SizedBox(height: 40),
                Text(
                  'الإصدار ${AppConstants.version}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: color.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.15)),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _url(String url) async {
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    }
  }

  void _suggestionDialog(BuildContext context) {
    final titleC = TextEditingController();
    final bodyC = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lightbulb_outline, color: AppTheme.accentGold, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('اقتراحك', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleC,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'العنوان',
                hintStyle: TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: Color(0xFF0D0520),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyC,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'التفاصيل',
                hintStyle: TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: Color(0xFF0D0520),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (titleC.text.trim().isNotEmpty && bodyC.text.trim().isNotEmpty) {
                context.read<AppProvider>().addSuggestion(titleC.text.trim(), bodyC.text.trim());
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم إرسال الاقتراح'), backgroundColor: AppTheme.success),
                );
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }
}