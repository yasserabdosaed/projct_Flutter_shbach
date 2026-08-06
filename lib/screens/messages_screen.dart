import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/admin_message.dart';
import '../providers/app_provider.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.campaign_rounded, color: AppTheme.accent, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('رسائل الإدارة', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
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
          child: Consumer<AppProvider>(
            builder: (context, provider, _) {
              if (provider.messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.cardDark.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mail_outline_rounded, size: 64, color: Color(0xFF455A64)),
                      ),
                      const SizedBox(height: 20),
                      const Text('لا توجد رسائل', style: TextStyle(color: AppTheme.textMuted, fontSize: 18)),
                      const SizedBox(height: 8),
                      const Text('عند إرسال الإدارة لرسالة ستظهر هنا', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    ],
                  ),
                );
              }

              // عرض الأحدث أولاً
              final reversed = provider.messages.reversed.toList();

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                itemCount: reversed.length,
                itemBuilder: (context, index) {
                  final msg = reversed[index];
                  return _MessageBubble(
                    message: msg,
                    isUnread: !msg.read,
                    onTap: () => provider.markMessageRead(msg.id),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final AdminMessage message;
  final bool isUnread;
  final VoidCallback onTap;

  const _MessageBubble({
    required this.message,
    required this.isUnread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          textDirection: TextDirection.rtl,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isUnread
                      ? [AppTheme.accent, AppTheme.accent.withValues(alpha: 0.5)]
                      : [Colors.white24, Colors.white12],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: isUnread
                    ? [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.2), blurRadius: 8)]
                    : null,
              ),
              child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isUnread
                      ? const Color(0xFF1A1F3A)
                      : const Color(0xFF12142A),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
                  border: Border.all(
                    color: isUnread
                        ? AppTheme.accent.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.04),
                    width: isUnread ? 1.2 : 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('الإدارة',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isUnread ? AppTheme.accent : AppTheme.textMuted,
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 7, height: 7,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.accent),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(message.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                    if (message.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(message.body,
                        style: TextStyle(
                          color: isUnread ? Colors.white.withValues(alpha: 0.85) : AppTheme.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 11, color: AppTheme.textMuted.withValues(alpha: 0.4)),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(message.createdAt),
                          style: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.4), fontSize: 10),
                        ),
                      ],
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

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return 'منذ ${diff.inMinutes} د';
    if (diff.inDays < 1) return 'منذ ${diff.inHours} س';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} ي';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}