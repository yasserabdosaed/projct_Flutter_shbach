import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import '../config/theme.dart';
import '../providers/app_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _dialogShown = false;
  late final WebViewController _webViewController;
  String? _gatewayIp;
  bool _isProcessing = false;
  String? _lastProcessedVoucher;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gatewayIp = context.read<AppProvider>().gatewayIp ?? '172.16.0.1';
      _checkBalance(context);
      _checkExistingLogin();
    });

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            await _checkStatus();
            await _readVoucherFromPage();
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.contains('login') && url.contains('callBack')) {
              Future.delayed(const Duration(seconds: 2), () {
                _checkStatus();
                _readVoucherFromPage();
              });
            }
            if (url.contains('status') && url.contains('callBack')) {
              _checkStatus();
            }
            return NavigationDecision.navigate;
          },
        ),
      );
  }

  // ===== قراءة الكرت من صفحة الويب =====
  Future<void> _readVoucherFromPage() async {
    try {
      final result = await _webViewController.runJavaScriptReturningResult('''
        (function(){
          var input = document.querySelector('input[name="username"]');
          if(input) return input.value;
          return '';
        })();
      ''');
      
      final voucher = result.toString().trim();
      if (voucher.isEmpty) return;

      final already = await context.read<AppProvider>().isVoucherProcessed(voucher);
      if (already || voucher == _lastProcessedVoucher) return;
      _lastProcessedVoucher = voucher;

      String category = await _determineCategoryFromPage();
      final provider = context.read<AppProvider>();
      await provider.handleSpinWheel(voucher, category: category);
    } catch (e) {
      // تجاهل الأخطاء
    }
  }

  // ===== تحديد فئة الكرت من الصفحة =====
  Future<String> _determineCategoryFromPage() async {
    try {
      final speedResult = await _webViewController.runJavaScriptReturningResult('''
        (function(){
          var select = document.querySelector('select[name="domain"]');
          if(select) return select.value;
          return '';
        })();
      ''');
      
      final speed = speedResult.toString();
      if (speed.contains('economic') || speed.contains('normal')) {
        return 'small';
      } else if (speed.contains('middle') || speed.contains('high') || speed.contains('very')) {
        return 'large';
      }
    } catch (e) {}
    
    try {
      final voucherResult = await _webViewController.runJavaScriptReturningResult('''
        (function(){
          var input = document.querySelector('input[name="username"]');
          if(input) return input.value;
          return '';
        })();
      ''');
      final voucher = voucherResult.toString().trim();
      if (voucher.isNotEmpty) {
        final firstDigit = int.tryParse(voucher[0]) ?? 0;
        if (firstDigit >= 5) return 'large';
      }
    } catch (e) {}
    
    return 'small';
  }

  // ===== فحص حالة تسجيل الدخول من الميكروتيك =====
  Future<void> _checkStatus() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final response = await http.get(
        Uri.parse('http://$_gatewayIp/status?var=callBack'),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isLoggedIn = data['logged_in'] == '1' || data['logged_in'] == true;
        final username = data['username'] ?? '';
        final speed = data['sps'] ?? '';

        if (isLoggedIn && username.isNotEmpty) {
          final already = await context.read<AppProvider>().isVoucherProcessed(username);
          if (already || username == _lastProcessedVoucher) return;
          _lastProcessedVoucher = username;

          String category = _determineCategoryFromSpeed(speed, username);
          final provider = context.read<AppProvider>();
          await provider.handleSpinWheel(username, category: category);
        }
      }
    } catch (e) {
      // تجاهل الأخطاء
    } finally {
      _isProcessing = false;
    }
  }

  // ===== تحديد الفئة من سرعة الكرت =====
  String _determineCategoryFromSpeed(String speed, String username) {
    if (speed.contains('economic') || speed.contains('normal')) {
      return 'small';
    } else if (speed.contains('middle') || speed.contains('high') || speed.contains('very')) {
      return 'large';
    }
    if (username.isNotEmpty) {
      final firstDigit = int.tryParse(username[0]) ?? 0;
      if (firstDigit >= 5) return 'large';
    }
    return 'small';
  }

  // ===== فحص الجلسة الحالية (دون إعادة احتساب النقاط) =====
  Future<void> _checkExistingLogin() async {
    final provider = context.read<AppProvider>();
    if (provider.isConnected && provider.voucher != null) {
      // فقط نتأكد من عدم تكرار الكرت المعالج مسبقاً
      final already = await provider.isVoucherProcessed(provider.voucher!);
      if (!already) {
        await provider.handleSpinWheel(provider.voucher!);
      }
    }
  }

  // ===== فحص الرصيد =====
  void _checkBalance(BuildContext context) {
    final provider = context.read<AppProvider>();
    if (provider.isLowBalance && !provider.lowBalanceShown && !_dialogShown) {
      _dialogShown = true;
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
            onPressed: () {
              context.read<AppProvider>().resetLowBalanceWarning();
              Navigator.of(ctx).pop();
              _dialogShown = false;
            },
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
    final url = context.read<AppProvider>().loginUrl;
    return Scaffold(
      body: SafeArea(
        child: WebViewWidget(
          controller: _webViewController
            ..loadRequest(Uri.parse(url)),
        ),
      ),
    );
  }
}