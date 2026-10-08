import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import '../config/theme.dart';
import '../providers/app_provider.dart';
import '../services/mikrotik_service.dart';

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
  bool _pageLoading = true;
  bool _pageError = false;
  bool _mainFrameFailed = false;
  bool _isDemoMode = false;
  String? _loadedUrl;
  Timer? _loadTimeout;
  String _primaryUrl = '';
  static const String _demoAsset = 'assets/demo/demo_login.html';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gatewayIp = context.read<AppProvider>().gatewayIp ?? '172.16.0.1';
      _checkBalance(context);
      _checkExistingLogin();
      _startInitialFlow();
    });

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            _mainFrameFailed = false;
            if (mounted) {
              setState(() {
                _pageLoading = true;
                _pageError = false;
              });
            }
            _startLoadTimeout();
          },
          onPageFinished: (url) async {
            _loadTimeout?.cancel();
            if (mounted) {
              setState(() {
                _pageLoading = false;
                _pageError = false;
              });
            }
            if (_mainFrameFailed) return;
            // الوضع التجريبي سلبي تماماً: نعرض الصفحة فقط ولا نحوّل أي كرت
            // ولا نزيد/ننقص أي نقطة. الاحتساب الحقيقي يحدث فقط في صفحة
            // تسجيل الدخول الفعلية عند الاتصال بشبكة الحارث أدناه.
            if (_isDemoMode) {
              return;
            }
            await _checkStatus();
            await _readVoucherFromPage();
            // قراءة الرصيد المتبقي من الصفحة الفعلية بعد تعبئتها بالجافاسكربت
            Future.delayed(const Duration(seconds: 4), () {
              if (mounted && !_isDemoMode) {
                _syncBalanceFromPage();
              }
            });
          },
          onWebResourceError: (error) {
            _loadTimeout?.cancel();
            if (error.isForMainFrame != true) return;
            _mainFrameFailed = true;
            if (mounted) {
              setState(() {
                _pageLoading = false;
                _pageError = true;
              });
            }
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

  @override
  void dispose() {
    _loadTimeout?.cancel();
    super.dispose();
  }

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

      final provider = context.read<AppProvider>();
      final already = await provider.isVoucherProcessed(voucher);
      debugPrint('[SPIN][DEBUG] _readVoucherFromPage: voucher=$voucher already=$already last=$_lastProcessedVoucher');
      if (already || voucher == _lastProcessedVoucher) return;

      if (!await _verifyVoucherLoggedIn(voucher)) return;
      _lastProcessedVoucher = voucher;

      String category = await _determineCategoryFromPage();
      if (category == 'none') {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: const Text(
                  'هذا الكرت (300 ميجا) لا يُحتسب في عجلة الحظ. يرجى إضافة كرت أكبر (600 ميجا فأكثر)'),
              duration: const Duration(seconds: 3),
              backgroundColor: AppTheme.accentOrange,
              behavior: SnackBarBehavior.floating,
            ));
        }
        return;
      }
      await provider.handleSpinWheel(voucher, category: category);
    } catch (e) {
      // تجاهل الأخطاء
    }
  }

  Future<bool> _verifyVoucherLoggedIn(String voucher) async {
    try {
      final response = await http.get(
        Uri.parse('http://$_gatewayIp/status?var=callBack'),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final parsed = _parseMikrotikStatus(response.body);
        final loggedIn = _isLoggedInValue(parsed['logged_in']);
        final username = parsed['username']?.toString() ?? '';
        return loggedIn && username == voucher;
      }
    } catch (_) {}
    return false;
  }

  /// محلّل مرن لحالة الميكروتيك يدعم عدة صيغ:
  /// 1) JSON صالح 2) JSON بعلامات اقتباس مفردة (Python-like)
  /// 3) var callBack = {...}; 4) query string
  /// ويكشف تسجيل الدخول بأي قيمة: 'yes' / '1' / true / 1
  Map<String, dynamic> _parseMikrotikStatus(String body) {
    final trimmed = body.trim();
    var jsonStr = trimmed;

    // استخراج كتلة الأقواس {...} إن وُجدت
    final braceStart = jsonStr.indexOf('{');
    final braceEnd = jsonStr.lastIndexOf('}');
    if (braceStart >= 0 && braceEnd > braceStart) {
      jsonStr = jsonStr.substring(braceStart, braceEnd + 1);
    }

    // محاولة JSON صالح أولاً
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry('$k', v));
      }
    } catch (_) {
      // ننتقل للصيغة ذات الاقتباسات المفردة
    }

    // تحويل الاقتباسات المفردة إلى مزدوجة (صيغة Python-like من الميكروتيك)
    try {
      final fixed = jsonStr.replaceAll("'", '"');
      final decoded = jsonDecode(fixed);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry('$k', v));
      }
    } catch (_) {
      // ننتقل لصيغة query string
    }

    // صيغة query string: logged_in=1&username=x
    final params = <String, dynamic>{};
    for (final seg in trimmed.split('&')) {
      final parts = seg.split('=');
      if (parts.isNotEmpty && parts[0].isNotEmpty) {
        params[parts[0].trim()] =
            (parts.length > 1 ? Uri.decodeComponent(parts[1]) : '').trim();
      }
    }
    if (params.containsKey('logged_in')) return params;
    return <String, dynamic>{};
  }

  /// يعود true إذا كانت قيمة logged_in تدل على نجاح تسجيل الدخول
  /// (يدعم: 'yes' / '1' / 1 / true / 'true')
  bool _isLoggedInValue(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    final s = v.toString().toLowerCase().trim();
    return s == 'yes' || s == '1' || s == 'true' || s == 'on';
  }

  /// يقرأ الرصيد المتبقي من الصفحة الفعلية (العنصر #remain_bytes_total)
  /// ويحدّثه في المزوّد حتى يظهر في الصفحة الرئيسية بالخط الأخضر.
  Future<void> _syncBalanceFromPage() async {
    try {
      final res = await _webViewController
          .runJavaScriptReturningResult('''
        (function(){
          var el = document.getElementById('remain_bytes_total');
          if(!el) return '';
          var raw = el.textContent || el.innerText || '';
          // إرجاع سلسلة منسّقة مثل "1.49 جيجابايت"
          return raw.replace(/[\\r\\n]+/g, ' ').trim();
        })();
      ''');
      final raw = res.toString().trim();
      if (raw.isEmpty || raw.contains('غير محدود') || raw.contains('unlimited')) {
        return;
      }
      int? bytes = _parseHumanBytes(raw);
      if (bytes != null && bytes > 0) {
        context.read<AppProvider>().setRemainingBalanceFromBytes(bytes);
      }
    } catch (_) {}
  }

  /// يحوّل نصاً مثل "1.49 جيجابايت" أو "500 ميجابايت" إلى بايت
  int? _parseHumanBytes(String raw) {
    final m = RegExp(r'([\d.]+)\s*(جيجابايت|جيجا|جيجا بايت|ميجابايت|ميجا بايت|ميجا|كيلوبايت|كيلو|كيلو بايت|GB|MB|KB|G|M|K)',
            caseSensitive: false)
        .firstMatch(raw);
    if (m == null) return null;
    final num = double.tryParse(m.group(1)!);
    if (num == null || num < 0) return null;
    final unit = m.group(2)!.toLowerCase();
    if (unit.startsWith('جيج') || unit == 'gb' || unit == 'g') {
      return (num * 1024 * 1024 * 1024).round();
    } else if (unit.startsWith('ميج') || unit == 'mb' || unit == 'm') {
      return (num * 1024 * 1024).round();
    } else {
      return (num * 1024).round();
    }
  }

  Future<String> _determineCategoryFromPage() async {    // في الوضع التجريبي نتجاوز اتصال جهاز الميكروتيك (غير موجود على المحاكي)
    // لنمنع انتظار المهلة (5-10 ثوانٍ) ونسرّع الاحتساب.
    if (_gatewayIp != null && !_isDemoMode) {
      try {
        final mikrotik = MikrotikService()
          ..setGatewayIp(_gatewayIp!);
        final cat = await mikrotik.determineVoucherCategory();
        if (cat != null) return cat;
      } catch (_) {}
    }

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
          var demo = document.getElementById('voucher');
          if(demo) return demo.value;
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

  Future<void> _checkStatus() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final response = await http.get(
        Uri.parse('http://$_gatewayIp/status?var=callBack'),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final parsed = _parseMikrotikStatus(response.body);
        final isLoggedIn = _isLoggedInValue(parsed['logged_in']);
        final username = parsed['username']?.toString() ?? '';
        final speed = parsed['sps']?.toString() ?? '';

        if (isLoggedIn && username.isNotEmpty) {
          final provider = context.read<AppProvider>();
          final already = await provider.isVoucherProcessed(username);
          debugPrint('[SPIN][DEBUG] _checkStatus: loggedIn=$isLoggedIn user=$username already=$already last=$_lastProcessedVoucher');
          if (already || username == _lastProcessedVoucher) {
            if (already && mounted) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text('الكرت $username مُحتسب مسبقاً، لا تكرار'),
                  duration: const Duration(seconds: 3),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                ));
            }
            return;
          }
          _lastProcessedVoucher = username;

          String category = await _determineCategoryFromSpeed(speed, username);
          if (category == 'none') {
            if (mounted) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: const Text(
                      'هذا الكرت (300 ميجا) لا يُحتسب في عجلة الحظ. يرجى إضافة كرت أكبر (600 ميجا فأكثر)'),
                  duration: const Duration(seconds: 3),
                  backgroundColor: AppTheme.accentOrange,
                  behavior: SnackBarBehavior.floating,
                ));
            }
            return;
          }
          await provider.handleSpinWheel(username, category: category);

          // مزامنة الرصيد المتبقي من الصفحة الفعلية (بعد مهلة قصيرة حتى
          // يكتمل تعبئة العنصر #remain_bytes_total بجافاسكربت الصفحة)
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              _syncBalanceFromPage();
            }
          });
          if (mounted) {
            final counter = category == 'small'
                ? provider.spinSmallCounter
                : provider.spinLargeCounter;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text('تم احتساب الكرت $username — العداد: $counter / 5'),
                duration: const Duration(seconds: 3),
                backgroundColor: AppTheme.success,
                behavior: SnackBarBehavior.floating,
              ));
          }
        } else if (mounted) {
          // تشخيص على الشاشة: أظهر محتوى الاستجابة ليُعرف سبب عدم الاحتساب
          final snippet = (response.body.length > 140)
              ? response.body.substring(0, 140)
              : response.body;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text('الحالة: logged_in=$isLoggedIn user=$username — $snippet'),
              duration: const Duration(seconds: 4),
              backgroundColor: const Color(0xFF3A3A3A),
              behavior: SnackBarBehavior.floating,
            ));
        }
      }
    } catch (e) {
      // تجاهل الأخطاء
    } finally {
      _isProcessing = false;
    }
  }

  Future<String> _determineCategoryFromSpeed(String speed, String username) async {
    // تحديد دقيق من إجمالي ميجا الكرت الفعلي
    if (_gatewayIp != null) {
      try {
        final mikrotik = MikrotikService()..setGatewayIp(_gatewayIp!);
        final cat = await mikrotik.determineVoucherCategory(fallbackSpeed: speed);
        if (cat != null) return cat;
      } catch (_) {}
    }

    // حماية إضافية: قراءة الرصيد المتبقي من الصفحة الفعلية ومقارنته بـ 1 جيجا
    // إذا الرصيد أكبر من 1 جيجا فالكرت كبير (نسبة كبرى)
    try {
      final res = await _webViewController.runJavaScriptReturningResult('''
        (function(){
          var el = document.getElementById('remain_bytes_total');
          if(!el) return '';
          return (el.textContent || el.innerText || '').trim();
        })();
      ''');
      final text = res.toString().trim();
      if (text.isNotEmpty && !text.contains('غير محدود') && !text.contains('unlimited')) {
        final m = RegExp(r'([\d.]+)\s*(جيجابايت|جيجا|GB|ميجابايت|ميجا|MB)', caseSensitive: false)
            .firstMatch(text);
        if (m != null) {
          final value = double.tryParse(m.group(1) ?? '') ?? 0;
          final unit = m.group(2)!.toLowerCase();
          final isGiga = unit.startsWith('جيج') || unit == 'gb';
          final isGigaValue = isGiga ? value : value / 1024;
          if (isGigaValue < 0.5) return 'none';        // 300 ميجا أو أقل
          if (isGigaValue > 1.15) return 'large';       // 1500 ميجا فأكثر
          return 'small';                               // 600 ميجا / 1 جيجا
        }
      }
    } catch (_) {}

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

  Future<void> _checkExistingLogin() async {
    final provider = context.read<AppProvider>();
    if (provider.isConnected && provider.voucher != null) {
      final already = await provider.isVoucherProcessed(provider.voucher!);
      debugPrint('[SPIN][DEBUG] _checkExistingLogin: voucher=${provider.voucher} already=$already');
      if (!already) {
        await provider.handleSpinWheel(provider.voucher!);
      }
    }
  }

  void _checkBalance(BuildContext context) {
    final provider = context.read<AppProvider>();
    if (provider.isLowBalance && !provider.lowBalanceShown && !_dialogShown) {
      _dialogShown = true;
      _showLowBalanceDialog(context, provider.remainingMB);
    }
  }

  void _startLoadTimeout() {
    _loadTimeout?.cancel();
    _loadTimeout = Timer(const Duration(seconds: 12), () {
      if (mounted && _pageLoading && !_pageError) {
        _mainFrameFailed = true;
        setState(() {
          _pageLoading = false;
          _pageError = true;
        });
      }
    });
  }

  void _startInitialFlow() {
    final provider = context.read<AppProvider>();
    final url = provider.loginUrl;
    _primaryUrl = url.isNotEmpty ? url : 'http://www.h.net/index.html';
    _probeNetwork();
  }

  Future<void> _probeNetwork() async {
    final gateway = _gatewayIp ?? '172.16.0.1';
    final reachable = await _isNetworkReachable('http://$gateway');
    if (!mounted) return;
    if (reachable) {
      _loadLoginPage();
    } else {
      _showDemoMode();
    }
  }

  Future<bool> _isNetworkReachable(String urlString) async {
    try {
      final uri = Uri.tryParse(urlString);
      if (uri == null || uri.host.isEmpty) return false;
      final socket = await Socket.connect(
        uri.host,
        uri.port,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _loadLoginPage() {
    if (!mounted) return;
    _isDemoMode = false;
    setState(() {
      _pageLoading = true;
      _pageError = false;
    });
    _loadTimeout?.cancel();
    _loadedUrl =
        _primaryUrl.isEmpty ? 'http://www.h.net/index.html' : _primaryUrl;
    _webViewController.loadRequest(Uri.parse(_loadedUrl!));
    _startLoadTimeout();
  }

  void _showDemoMode() {
    if (!mounted) return;
    _isDemoMode = true;
    _loadTimeout?.cancel();
    setState(() {
      _pageLoading = true;
      _pageError = false;
    });
    // الوضع التجريبي: نعرض صفحة تجريبية فقط دون أي احتساب
    _webViewController.loadFlutterAsset(_demoAsset);
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
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _webViewController),
            if (_isDemoMode)
              Positioned(
                left: 0, right: 0, top: 0,
                child: Material(
                  color: AppTheme.accentGold.withValues(alpha: 0.95),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.preview_rounded, size: 18, color: Color(0xFF2D1B69)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'وضع تجريبي - الخدمة متاحة عند الاتصال بالشبكة',
                            style: TextStyle(
                              color: Color(0xFF2D1B69),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadLoginPage,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF2D1B69),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 32),
                          ),
                          child: const Text('الرابط الفعلي', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_pageLoading && !_pageError && !_isDemoMode)
              Center(
                child: CircularProgressIndicator(
                  color: AppTheme.accent,
                  strokeWidth: 3,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
