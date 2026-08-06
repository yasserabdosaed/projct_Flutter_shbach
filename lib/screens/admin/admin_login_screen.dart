import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/storage_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _passwordC = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _loading = false;
  bool _superMode = false;
  int _tapCount = 0;
  String? _error;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    final provider = context.read<AppProvider>();
    final valid = _superMode
        ? await provider.verifySuperAdminPassword(_passwordC.text.trim())
        : await provider.verifyAdminPassword(_passwordC.text.trim());
    if (!mounted) return;
    if (valid) {
      if (_superMode) {
        StorageService().setSuperAdminLoggedIn(true);
        provider.setSuperAdmin(true);
        Navigator.of(context).pushReplacementNamed(AppRoutes.adminPanel);
      } else {
        StorageService().setAdminLoggedIn(true);
        provider.setSuperAdmin(false);
        Navigator.of(context).pushReplacementNamed(AppRoutes.adminPanel);
      }
    } else {
      setState(() { _loading = false; _error = 'كلمة المرور غير صحيحة'; });
    }
  }

  void _onLockTap() {
    _tapCount++;
    if (_tapCount >= 7) {
      _tapCount = 0;
      setState(() => _superMode = !_superMode);
    }
  }

  @override
  void dispose() {
    _passwordC.dispose();
    super.dispose();
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _onLockTap,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _superMode
                                ? [AppTheme.error, AppTheme.error.withValues(alpha: 0.5)]
                                : [AppTheme.accent, AppTheme.accent.withValues(alpha: 0.5)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_superMode ? AppTheme.error : AppTheme.accent)
                                  .withValues(alpha: 0.3),
                              blurRadius: 40,
                            ),
                          ],
                        ),
                        child: Icon(
                          _superMode ? Icons.security_rounded : Icons.admin_panel_settings_rounded,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      _superMode ? 'الدخول السري' : 'لوحة الإدارة',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _superMode ? AppTheme.error : Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (_superMode)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'تحكم كامل بالنظام',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.error.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    const SizedBox(height: 36),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: AppTheme.glassCardDecoration,
                      child: Column(
                        children: [
                          if (_error != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.error.withValues(alpha: 0.15)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                                  const SizedBox(width: 8),
                                  Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
                                ],
                              ),
                            ),
                          TextFormField(
                            controller: _passwordC,
                            obscureText: _obscure,
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              labelStyle: const TextStyle(color: AppTheme.textMuted),
                              prefixIcon: Icon(
                                Icons.lock_outline_rounded,
                                color: _superMode ? AppTheme.error : AppTheme.accent,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  color: AppTheme.textMuted,
                                ),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF0D1B2A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: _superMode ? AppTheme.error : AppTheme.accent,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'الرجاء إدخال كلمة المرور' : null,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _superMode ? AppTheme.error : AppTheme.accent,
                                disabledBackgroundColor: (_superMode ? AppTheme.error : AppTheme.accent)
                                    .withValues(alpha: 0.3),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                elevation: 10,
                                shadowColor: (_superMode ? AppTheme.error : AppTheme.accent)
                                    .withValues(alpha: 0.4),
                              ),
                              child: _loading
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('دخول', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}