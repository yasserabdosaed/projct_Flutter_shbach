import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // مهم لـ Clipboard
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/admin_message.dart';
import '../../models/spin_prize.dart';
import '../../providers/app_provider.dart';
import '../../services/storage_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final isSuper = context.watch<AppProvider>().isSuperAdmin;
    final accentColor = isSuper ? AppTheme.error : AppTheme.accent;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          children: [
            if (isSuper)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'SUPER',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.error),
                ),
              ),
            Text(
              isSuper ? 'التحكم الكامل' : 'لوحة الإدارة',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout_rounded, size: 20),
            ),
            onPressed: () {
              if (isSuper) {
                StorageService().setSuperAdminLoggedIn(false);
                context.read<AppProvider>().setSuperAdmin(false);
              } else {
                StorageService().setAdminLoggedIn(false);
              }
              Navigator.of(context).pushReplacementNamed(AppRoutes.adminLogin);
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 0.8,
            colors: [Color(0xFF0F1F3A), Color(0xFF060E1A)],
          ),
        ),
        child: SafeArea(
          child: isSuper
              ? (_tab == 0
                  ? const _SendMsg()
                  : _tab == 1
                      ? const _Settings()
                      : _tab == 2
                          ? const _SpinWheelSettings()
                          : _tab == 3
                              ? const _SuggestionsList()
                              : _tab == 4
                                  ? const _AdminPassword()
                                  : _tab == 5
                                      ? const _UsersList()
                                      : const _SuperPassword())
              : (_tab == 0
                  ? const _SendMsg()
                  : _tab == 1
                      ? const _Settings()
                      : _tab == 2
                          ? const _SpinWheelSettings()
                          : _tab == 3
                              ? const _SuggestionsList()
                              : const _UsersList()),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A1628),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: isSuper ? _superTabs(accentColor) : _ownerTabs(accentColor),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _superTabs(Color accent) => [
        _navItem(Icons.send_rounded, 'إرسال', 0, accent),
        _navItem(Icons.settings_rounded, 'إعدادات', 1, accent),
        _navItem(Icons.casino_rounded, 'عجلة الحظ', 2, accent),
        _navItem(Icons.inbox_rounded, 'اقتراحات', 3, accent),
        _navItem(Icons.admin_panel_settings_rounded, 'مسؤول', 4, accent),
        _navItem(Icons.people_rounded, 'مستخدمين', 5, accent),
        _navItem(Icons.security_rounded, 'سرية', 6, accent),
      ];

  List<Widget> _ownerTabs(Color accent) => [
        _navItem(Icons.send_rounded, 'إرسال', 0, accent),
        _navItem(Icons.settings_rounded, 'إعدادات', 1, accent),
        _navItem(Icons.casino_rounded, 'عجلة الحظ', 2, accent),
        _navItem(Icons.inbox_rounded, 'اقتراحات', 3, accent),
        _navItem(Icons.people_rounded, 'مستخدمين', 4, accent),
      ];

  Widget _navItem(IconData icon, String label, int index, Color accent) {
    final sel = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: sel ? accent : const Color(0xFF607D8B)),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: sel ? accent : const Color(0xFF607D8B),
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========================== إرسال رسالة ==========================
class _SendMsg extends StatefulWidget {
  const _SendMsg();

  @override
  State<_SendMsg> createState() => _SendMsgState();
}

class _SendMsgState extends State<_SendMsg> {
  final _tC = TextEditingController();
  final _bC = TextEditingController();
  final _fKey = GlobalKey<FormState>();

  String? _editingId;
  AdminMessage? _editingMessage;

  @override
  void dispose() {
    _tC.dispose();
    _bC.dispose();
    super.dispose();
  }

  void _clearForm() {
    _tC.clear();
    _bC.clear();
    setState(() {
      _editingId = null;
      _editingMessage = null;
    });
  }

  void _loadMessageForEdit(AdminMessage msg) {
    setState(() {
      _editingId = msg.id;
      _editingMessage = msg;
      _tC.text = msg.title;
      _bC.text = msg.body;
    });
  }

  void _sendOrUpdate() {
    if (!_fKey.currentState!.validate()) return;

    final title = _tC.text.trim();
    final body = _bC.text.trim();

    if (_editingId != null) {
      context.read<AppProvider>().updateAdminMessage(_editingId!, title, body);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث الرسالة بنجاح'),
          backgroundColor: AppTheme.success,
        ),
      );
    } else {
      context.read<AppProvider>().sendAdminMessage(title, body);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال الرسالة'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
    _clearForm();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Form(
            key: _fKey,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.glassCardDecoration,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _editingId != null ? Icons.edit_rounded : Icons.send_rounded,
                      size: 48,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _editingId != null ? 'تعديل الرسالة' : 'إرسال رسالة للمستخدمين',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  if (_editingId != null)
                    Text(
                      'تعديل: ${_editingMessage?.title}',
                      style: const TextStyle(color: AppTheme.accentGold, fontSize: 14),
                    ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _tC,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'عنوان الرسالة',
                      labelStyle: const TextStyle(color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.title_rounded, color: AppTheme.accent),
                      filled: true,
                      fillColor: const Color(0xFF0D1B2A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bC,
                    maxLines: 5,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'محتوى الرسالة',
                      labelStyle: const TextStyle(color: AppTheme.textMuted),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 80),
                        child: Icon(Icons.description_rounded, color: AppTheme.accent),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0D1B2A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (_editingId != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _clearForm,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textMuted,
                              side: BorderSide(color: AppTheme.textMuted.withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('إلغاء'),
                          ),
                        ),
                      if (_editingId != null) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _sendOrUpdate,
                          icon: Icon(_editingId != null ? Icons.save_rounded : Icons.send_rounded),
                          label: Text(
                            _editingId != null ? 'تحديث الرسالة' : 'إرسال للجميع',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _editingId != null ? AppTheme.accentGold : AppTheme.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: 10,
                            shadowColor: (_editingId != null ? AppTheme.accentGold : AppTheme.accent)
                                .withValues(alpha: 0.4),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _MessagesList(),
        ],
      ),
    );
  }
}

// ========================== قائمة الرسائل ==========================
class _MessagesList extends StatelessWidget {
  const _MessagesList();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        if (provider.messages.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الرسائل المرسلة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.messages.length > 5 ? 5 : provider.messages.length,
              itemBuilder: (context, index) {
                final msg = provider.messages[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: AppTheme.glassDecoration,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              msg.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: AppTheme.accent, size: 22),
                        onPressed: () {
                          final sendMsgState = context.findAncestorStateOfType<_SendMsgState>();
                          if (sendMsgState != null) {
                            sendMsgState._loadMessageForEdit(msg);
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            if (provider.messages.length > 5)
              TextButton(
                onPressed: () {},
                child: const Text('عرض الكل', style: TextStyle(color: AppTheme.accent)),
              ),
          ],
        );
      },
    );
  }
}

// ========================== إعدادات عجلة الحظ ==========================
class _SpinWheelSettings extends StatefulWidget {
  const _SpinWheelSettings();

  @override
  State<_SpinWheelSettings> createState() => _SpinWheelSettingsState();
}

class _SpinWheelSettingsState extends State<_SpinWheelSettings> {
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  String _selectedType = 'small';
  String? _editingId;

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _nameController.clear();
    _valueController.clear();
    setState(() {
      _editingId = null;
      _selectedType = 'small';
    });
  }

  void _loadPrizeForEdit(SpinPrize prize) {
    setState(() {
      _editingId = prize.id;
      _nameController.text = prize.name;
      _valueController.text = prize.value;
      _selectedType = prize.type;
    });
  }

  Future<void> _savePrize() async {
    final name = _nameController.text.trim();
    final value = _valueController.text.trim();
    if (name.isEmpty || value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى ملء جميع الحقول'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final provider = context.read<AppProvider>();
    if (_editingId != null) {
      await provider.updateSpinPrize(_editingId!, name, value, _selectedType);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث الجائزة'),
          backgroundColor: AppTheme.success,
        ),
      );
    } else {
      await provider.addSpinPrize(name, value, _selectedType);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إضافة الجائزة'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
    _clearForm();
  }

  Future<void> _deletePrize(String id) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذه الجائزة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              context.read<AppProvider>().deleteSpinPrize(id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم حذف الجائزة'),
                  backgroundColor: AppTheme.success,
                ),
              );
            },
            child: const Text('حذف', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // نموذج إضافة/تعديل
          Container(
            padding: const EdgeInsets.all(24),
            decoration: AppTheme.glassCardDecoration,
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _editingId != null ? Icons.edit_rounded : Icons.add_rounded,
                        color: AppTheme.accentGold,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _editingId != null ? 'تعديل جائزة' : 'إضافة جائزة جديدة',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'اسم الجائزة (مثل: 300 ميجا)',
                    labelStyle: TextStyle(color: AppTheme.textMuted),
                    prefixIcon: Icon(Icons.emoji_events_rounded, color: AppTheme.accentGold),
                    filled: true,
                    fillColor: Color(0xFF0D1B2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide(color: AppTheme.accentGold, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _valueController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'القيمة (مثل: 300)',
                    labelStyle: TextStyle(color: AppTheme.textMuted),
                    prefixIcon: Icon(Icons.numbers_rounded, color: AppTheme.accentGold),
                    filled: true,
                    fillColor: Color(0xFF0D1B2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide(color: AppTheme.accentGold, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'نوع الجائزة',
                    labelStyle: TextStyle(color: AppTheme.textMuted),
                    prefixIcon: Icon(Icons.category_rounded, color: AppTheme.accentGold),
                    filled: true,
                    fillColor: Color(0xFF0D1B2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide(color: AppTheme.accentGold, width: 1.5),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'small', child: Text('جوائز صغيرة')),
                    DropdownMenuItem(value: 'large', child: Text('جوائز كبيرة')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedType = value);
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (_editingId != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _clearForm,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textMuted,
                            side: BorderSide(color: AppTheme.textMuted.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('إلغاء'),
                        ),
                      ),
                    if (_editingId != null) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _savePrize,
                        icon: Icon(_editingId != null ? Icons.save_rounded : Icons.add_rounded),
                        label: Text(
                          _editingId != null ? 'تحديث الجائزة' : 'إضافة جائزة',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D1B2A), fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentGold,
                          foregroundColor: const Color(0xFF0D1B2A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 10,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // قائمة الجوائز
          const Text(
            'الجوائز الحالية',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Consumer<AppProvider>(
            builder: (context, provider, _) {
              final prizes = provider.spinPrizes;
              if (prizes.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: AppTheme.glassCardDecoration,
                  child: const Text(
                    'لا توجد جوائز حالياً، أضف جائزة جديدة',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: prizes.length,
                itemBuilder: (context, index) {
                  final prize = prizes[index];
                  final isSmall = prize.type == 'small';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.glassCardDecoration.copyWith(
                      border: Border.all(
                        color: isSmall ? AppTheme.accentGold.withValues(alpha: 0.3) : AppTheme.accentOrange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSmall ? AppTheme.accentGold.withValues(alpha: 0.1) : AppTheme.accentOrange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isSmall ? Icons.star_rounded : Icons.emoji_events_rounded,
                            color: isSmall ? AppTheme.accentGold : AppTheme.accentOrange,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prize.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                'القيمة: ${prize.value} | النوع: ${isSmall ? 'صغيرة' : 'كبيرة'}',
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, color: AppTheme.accent, size: 22),
                          onPressed: () => _loadPrizeForEdit(prize),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_rounded, color: AppTheme.error, size: 22),
                          onPressed: () => _deletePrize(prize.id),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ========================== الإعدادات ==========================
class _Settings extends StatefulWidget {
  const _Settings();

  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  late TextEditingController _loginC;
  late TextEditingController _liveC;
  late TextEditingController _restC;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppProvider>();
    _loginC = TextEditingController(text: p.loginUrl);
    _liveC = TextEditingController(text: p.liveUrl);
    _restC = TextEditingController(text: p.restUrl);
  }

  @override
  void dispose() {
    _loginC.dispose();
    _liveC.dispose();
    _restC.dispose();
    super.dispose();
  }

  void _saveUrls() {
    final p = context.read<AppProvider>();
    p.updateLoginUrl(_loginC.text.trim());
    p.updateLiveUrl(_liveC.text.trim());
    p.updateRestUrl(_restC.text.trim());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ الإعدادات'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: AppTheme.glassCardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.link_rounded, color: AppTheme.accent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'الروابط',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'رابط تسجيل الدخول',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _loginC,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppTheme.accent),
                    filled: true,
                    fillColor: const Color(0xFF0D1B2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'رابط البث المباشر',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _liveC,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.videocam_rounded, color: AppTheme.accent),
                    filled: true,
                    fillColor: const Color(0xFF0D1B2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'رابط الاستراحة',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _restC,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.hotel_rounded, color: AppTheme.accent),
                    filled: true,
                    fillColor: const Color(0xFF0D1B2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _saveUrls,
                    icon: const Icon(Icons.save_rounded, size: 20),
                    label: const Text(
                      'حفظ الروابط',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const _AppSettings(),
        ],
      ),
    );
  }
}

// ========================== الشعار والتواصل ==========================
class _AppSettings extends StatefulWidget {
  const _AppSettings();

  @override
  State<_AppSettings> createState() => _AppSettingsState();
}

class _AppSettingsState extends State<_AppSettings> {
  late TextEditingController _waC;
  late TextEditingController _phC;
  late TextEditingController _waGroupC;
  bool _uploading = false;

  final _pCurrentC = TextEditingController();
  final _pNewC = TextEditingController();
  final _pConfirmC = TextEditingController();
  bool _pLoading = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppProvider>();
    _waC = TextEditingController(text: p.whatsapp);
    _phC = TextEditingController(text: p.phone);
    _waGroupC = TextEditingController(text: p.whatsappGroup);
  }

  @override
  void dispose() {
    _waC.dispose();
    _phC.dispose();
    _waGroupC.dispose();
    _pCurrentC.dispose();
    _pNewC.dispose();
    _pConfirmC.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    setState(() => _uploading = true);
    await context.read<AppProvider>().pickAndSaveLogo();
    if (mounted) setState(() => _uploading = false);
  }

  void _saveContactInfo() {
    final p = context.read<AppProvider>();
    p.saveWhatsapp(_waC.text.trim());
    p.savePhone(_phC.text.trim());
    p.saveWhatsappGroup(_waGroupC.text.trim());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ معلومات التواصل'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  void _changePassword() {
    final cur = _pCurrentC.text.trim();
    final nw = _pNewC.text.trim();
    final conf = _pConfirmC.text.trim();
    if (cur.isEmpty || nw.isEmpty || conf.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى ملء جميع الحقول'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    if (nw != conf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كلمة المرور الجديدة غير متطابقة'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    setState(() => _pLoading = true);
    context.read<AppProvider>().updateAdminPassword(cur, nw).then((ok) {
      if (!mounted) return;
      setState(() => _pLoading = false);
      if (ok) {
        _pCurrentC.clear();
        _pNewC.clear();
        _pConfirmC.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تغيير كلمة المرور بنجاح'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('كلمة المرور الحالية غير صحيحة أو فشل الاتصال'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.palette_rounded, color: AppTheme.accentGold, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'الشعار والتواصل',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'شعار التطبيق',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 80,
                  height: 80,
                  color: const Color(0xFF0D1B2A),
                  child: p.logoPath != null && File(p.logoPath!).existsSync()
                      ? Image.file(File(p.logoPath!), width: 80, height: 80, fit: BoxFit.cover)
                      : Image.asset('assets/images/nn.jpeg', width: 80, height: 80, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'اختر صورة من المعرض',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _uploading ? null : _pickLogo,
                        icon: _uploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D1B2A)),
                              )
                            : const Icon(Icons.image_rounded, size: 18),
                        label: Text(_uploading ? 'جاري الرفع...' : 'تغيير الشعار'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentGold,
                          foregroundColor: const Color(0xFF0D1B2A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'روابط التواصل',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _waC,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'رقم واتساب (بدون +)',
              labelStyle: const TextStyle(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
              filled: true,
              fillColor: const Color(0xFF0D1B2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF25D366), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phC,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'رقم الهاتف',
              labelStyle: const TextStyle(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.phone_rounded, color: AppTheme.accent),
              filled: true,
              fillColor: const Color(0xFF0D1B2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _waGroupC,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'رابط مجموعة واتساب',
              labelStyle: const TextStyle(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.group_add_rounded, color: Color(0xFF25D366)),
              filled: true,
              fillColor: const Color(0xFF0D1B2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF25D366), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _saveContactInfo,
              icon: const Icon(Icons.save_rounded, size: 20),
              label: const Text(
                'حفظ معلومات التواصل',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D1B2A), fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGold,
                foregroundColor: const Color(0xFF0D1B2A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lock_rounded, color: AppTheme.accentGold, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'تغيير كلمة المرور',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _pCurrentC,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'كلمة المرور الحالية',
              labelStyle: const TextStyle(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.accentGold),
              filled: true,
              fillColor: const Color(0xFF0D1B2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.accentGold, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pNewC,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'كلمة المرور الجديدة',
              labelStyle: const TextStyle(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.lock_rounded, color: AppTheme.accentGold),
              filled: true,
              fillColor: const Color(0xFF0D1B2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.accentGold, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pConfirmC,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'تأكيد كلمة المرور',
              labelStyle: const TextStyle(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.lock_rounded, color: AppTheme.accentGold),
              filled: true,
              fillColor: const Color(0xFF0D1B2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.accentGold, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _pLoading ? null : _changePassword,
              icon: _pLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D1B2A)),
                    )
                  : const Icon(Icons.lock_rounded, size: 20),
              label: Text(
                _pLoading ? 'جاري الحفظ...' : 'تغيير كلمة المرور',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D1B2A), fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGold,
                foregroundColor: const Color(0xFF0D1B2A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ========================== قائمة الاقتراحات ==========================
class _SuggestionsList extends StatelessWidget {
  const _SuggestionsList();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        if (provider.suggestions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: AppTheme.textMuted),
                SizedBox(height: 12),
                Text('لا توجد اقتراحات', style: TextStyle(color: AppTheme.textMuted)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.suggestions.length,
          itemBuilder: (context, index) {
            final s = provider.suggestions[index];
            final isPending = s.status == 'pending';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
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
                  color: isPending
                      ? AppTheme.accentGold.withValues(alpha: 0.2)
                      : Colors.green.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isPending
                        ? AppTheme.accentGold.withValues(alpha: 0.05)
                        : Colors.green.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isPending
                          ? AppTheme.accentGold.withValues(alpha: 0.1)
                          : Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isPending ? Icons.pending_outlined : Icons.check_circle_outline,
                      color: isPending ? AppTheme.accentGold : Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.body,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: AppTheme.textMuted.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(s.createdAt),
                              style: TextStyle(
                                color: AppTheme.textMuted.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: isPending
                                    ? AppTheme.accentGold.withValues(alpha: 0.15)
                                    : Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isPending ? 'قيد المراجعة' : 'تمت',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isPending ? AppTheme.accentGold : Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inDays < 1) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ========================== قائمة المستخدمين ==========================
class _UsersList extends StatefulWidget {
  const _UsersList();

  @override
  State<_UsersList> createState() => _UsersListState();
}

class _UsersListState extends State<_UsersList> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: context.read<AppProvider>().getUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline_rounded, size: 64, color: Color(0xFF455A64)),
                SizedBox(height: 12),
                Text('لا يوجد مستخدمين', style: TextStyle(color: AppTheme.textMuted)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final voucher = user['voucher'] as String? ?? '---';
            final blocked = user['blocked'] as bool? ?? false;
            final token = user['docId'] as String? ?? user['fcmToken'] as String? ?? '';
            final lastActive = (user['lastActive'] as dynamic)?.toDate() as DateTime?;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.glassCardDecoration.copyWith(
                border: Border.all(
                  color: blocked
                      ? AppTheme.error.withValues(alpha: 0.2)
                      : AppTheme.success.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: blocked
                          ? AppTheme.error.withValues(alpha: 0.1)
                          : AppTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      blocked ? Icons.block_rounded : Icons.person_rounded,
                      color: blocked ? AppTheme.error : AppTheme.success,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'رمز: $voucher',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: blocked ? AppTheme.error : AppTheme.success,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              blocked ? 'محظور' : 'نشط',
                              style: TextStyle(
                                color: blocked ? AppTheme.error : AppTheme.success,
                                fontSize: 13,
                              ),
                            ),
                            if (lastActive != null) ...[
                              const SizedBox(width: 12),
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: AppTheme.textMuted.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatLastActive(lastActive),
                                style: TextStyle(
                                  color: AppTheme.textMuted.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (token.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        blocked ? Icons.check_circle_outline_rounded : Icons.block_rounded,
                        color: blocked ? AppTheme.success : AppTheme.error,
                      ),
                      onPressed: () {
                        context.read<AppProvider>().toggleUserBlock(token, !blocked);
                      },
                      tooltip: blocked ? 'إلغاء الحظر' : 'حظر',
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatLastActive(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inDays < 1) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ========================== كلمة مرور المسؤول ==========================
class _AdminPassword extends StatefulWidget {
  const _AdminPassword();

  @override
  State<_AdminPassword> createState() => _AdminPasswordState();
}

class _AdminPasswordState extends State<_AdminPassword> {
  final _newC = TextEditingController();
  final _confirmC = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _fetching = true;
  String? _msg;
  String? _currentPassword;
  bool _showCurrentPassword = true;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _loadPassword();
  }

  Future<void> _loadPassword() async {
    setState(() => _fetching = true);
    final pwd = await context.read<AppProvider>().getNetworkAdminPassword();
    if (!mounted) return;
    setState(() {
      _fetching = false;
      _currentPassword = pwd;
    });
  }

  @override
  void dispose() {
    _newC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  Future<void> _copyPassword() async {
    if (_currentPassword != null && _currentPassword!.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: _currentPassword!));
      setState(() => _copied = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نسخ كلمة المرور'),
          backgroundColor: AppTheme.success,
          duration: Duration(seconds: 1),
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _copied = false);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newC.text != _confirmC.text) {
      setState(() => _msg = 'كلمة المرور الجديدة غير متطابقة');
      return;
    }
    setState(() {
      _loading = true;
      _msg = null;
    });
    try {
      final ok = await context.read<AppProvider>().setNetworkAdminPassword(_newC.text.trim());
      if (!mounted) return;
      if (ok) {
        _currentPassword = _newC.text.trim();
        _newC.clear();
        _confirmC.clear();
        setState(() {
          _loading = false;
          _msg = 'تم تغيير كلمة مرور المسؤول بنجاح';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث كلمة مرور المسؤول'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        setState(() {
          _loading = false;
          _msg = 'فشل الحفظ، تأكد من اتصال Firebase';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _msg = 'حدث خطأ: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fetching) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.cardDark.withValues(alpha: 0.9),
                  AppTheme.cardDark.withValues(alpha: 0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.error.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded, size: 36, color: AppTheme.error),
                ),
                const SizedBox(height: 14),
                const Text(
                  '🔑 كلمة مرور المسؤول الحالية',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1B2A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          _showCurrentPassword ? Icons.visibility : Icons.visibility_off,
                          color: AppTheme.textMuted,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() => _showCurrentPassword = !_showCurrentPassword);
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _showCurrentPassword
                              ? (_currentPassword ?? 'غير معروفة')
                              : '••••••••••••',
                          style: TextStyle(
                            color: _currentPassword != null ? AppTheme.accentGold : AppTheme.textMuted,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          _copied ? Icons.check_circle_rounded : Icons.copy_rounded,
                          color: _copied ? AppTheme.success : AppTheme.textMuted,
                          size: 22,
                        ),
                        onPressed: _currentPassword != null && _currentPassword!.isNotEmpty
                            ? _copyPassword
                            : null,
                        tooltip: 'نسخ كلمة المرور',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'يمكنك تغييرها من خلال الحقول أدناه',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          Form(
            key: _formKey,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.glassCardDecoration,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGold.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.password_rounded, size: 40, color: AppTheme.accentGold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'تعيين كلمة مرور جديدة للمسؤول',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'أدخل كلمة مرور قوية مكونة من 4 أحرف على الأقل',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_msg != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: (_msg!.contains('فشل') || _msg!.contains('خطأ'))
                            ? AppTheme.error.withValues(alpha: 0.12)
                            : AppTheme.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: (_msg!.contains('فشل') || _msg!.contains('خطأ'))
                              ? AppTheme.error.withValues(alpha: 0.2)
                              : AppTheme.success.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            (_msg!.contains('فشل') || _msg!.contains('خطأ'))
                                ? Icons.error_outline
                                : Icons.check_circle_outline,
                            color: (_msg!.contains('فشل') || _msg!.contains('خطأ'))
                                ? AppTheme.error
                                : AppTheme.success,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _msg!,
                              style: TextStyle(
                                color: (_msg!.contains('فشل') || _msg!.contains('خطأ'))
                                    ? AppTheme.error
                                    : AppTheme.success,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextFormField(
                    controller: _newC,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الجديدة للمسؤول',
                      labelStyle: const TextStyle(color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.lock_rounded, color: AppTheme.accentGold),
                      filled: true,
                      fillColor: const Color(0xFF0D1B2A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.accentGold, width: 1.5),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 4) ? 'يجب أن تكون 4 أحرف على الأقل' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmC,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'تأكيد كلمة المرور',
                      labelStyle: const TextStyle(color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.lock_rounded, color: AppTheme.accentGold),
                      filled: true,
                      fillColor: const Color(0xFF0D1B2A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.accentGold, width: 1.5),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _save,
                      icon: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D1B2A)),
                            )
                          : const Icon(Icons.save_rounded, size: 22),
                      label: Text(
                        _loading ? 'جاري الحفظ...' : 'حفظ كلمة المسؤول',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D1B2A),
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGold,
                        foregroundColor: const Color(0xFF0D1B2A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 10,
                        shadowColor: AppTheme.accentGold.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ========================== كلمة المرور السرية ==========================
class _SuperPassword extends StatefulWidget {
  const _SuperPassword();

  @override
  State<_SuperPassword> createState() => _SuperPasswordState();
}

class _SuperPasswordState extends State<_SuperPassword> {
  final _currentC = TextEditingController();
  final _newC = TextEditingController();
  final _confirmC = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _msg;

  @override
  void dispose() {
    _currentC.dispose();
    _newC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newC.text != _confirmC.text) {
      setState(() => _msg = 'كلمة المرور الجديدة غير متطابقة');
      return;
    }
    setState(() {
      _loading = true;
      _msg = null;
    });
    try {
      final ok = await context.read<AppProvider>().updateSuperAdminPassword(
            _currentC.text.trim(),
            _newC.text.trim(),
          );
      if (!mounted) return;
      if (ok) {
        _currentC.clear();
        _newC.clear();
        _confirmC.clear();
        setState(() {
          _loading = false;
          _msg = 'تم تغيير كلمة المرور السرية بنجاح';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث كلمة المرور السرية'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        setState(() {
          _loading = false;
          _msg = 'كلمة المرور الحالية غير صحيحة أو فشل الاتصال';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _msg = 'حدث خطأ: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.glassCardDecoration,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.security_rounded, size: 48, color: AppTheme.error),
              ),
              const SizedBox(height: 16),
              const Text(
                'تغيير كلمة المرور السرية',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'خاص بمالك البرنامج فقط',
                style: TextStyle(fontSize: 13, color: AppTheme.error.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 24),
              if (_msg != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: (_msg!.contains('خطأ') || _msg!.contains('غير') || _msg!.contains('فشل'))
                        ? AppTheme.error.withValues(alpha: 0.1)
                        : AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        (_msg!.contains('خطأ') || _msg!.contains('غير') || _msg!.contains('فشل'))
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        color: (_msg!.contains('خطأ') || _msg!.contains('غير') || _msg!.contains('فشل'))
                            ? AppTheme.error
                            : AppTheme.success,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _msg!,
                          style: TextStyle(
                            color: (_msg!.contains('خطأ') || _msg!.contains('غير') || _msg!.contains('فشل'))
                                ? AppTheme.error
                                : AppTheme.success,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              TextFormField(
                controller: _currentC,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'كلمة المرور الحالية',
                  labelStyle: const TextStyle(color: AppTheme.textMuted),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.error),
                  filled: true,
                  fillColor: const Color(0xFF0D1B2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newC,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                  labelStyle: const TextStyle(color: AppTheme.textMuted),
                  prefixIcon: const Icon(Icons.lock_rounded, color: AppTheme.error),
                  filled: true,
                  fillColor: const Color(0xFF0D1B2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
                  ),
                ),
                validator: (v) => (v == null || v.trim().length < 4) ? '4 أحرف على الأقل' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmC,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                  labelStyle: const TextStyle(color: AppTheme.textMuted),
                  prefixIcon: const Icon(Icons.lock_rounded, color: AppTheme.error),
                  filled: true,
                  fillColor: const Color(0xFF0D1B2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _save,
                  icon: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded, size: 22),
                  label: const Text(
                    'حفظ',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 10,
                    shadowColor: AppTheme.error.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}