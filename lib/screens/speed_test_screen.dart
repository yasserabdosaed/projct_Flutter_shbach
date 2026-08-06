import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../config/theme.dart';

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen>
    with TickerProviderStateMixin {
  bool _isTesting = false;
  bool _done = false;
  double _downloadMbps = 0;
  double _uploadMbps = 0;
  int _pingMs = 0;
  String _status = 'اضغط لبدء فحص السرعة';

  late AnimationController _spinController;
  late AnimationController _gaugeController;
  late Animation<double> _gaugeAnim;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _gaugeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _gaugeAnim = CurvedAnimation(parent: _gaugeController, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _spinController.dispose();
    _gaugeController.dispose();
    super.dispose();
  }

  Future<void> _startTest() async {
    setState(() {
      _isTesting = true;
      _done = false;
      _downloadMbps = 0;
      _uploadMbps = 0;
      _pingMs = 0;
      _status = 'جاري اختبار زمن الاستجابة...';
    });
    _spinController.repeat();

    _pingMs = await _measurePing();
    if (!mounted) return;

    setState(() => _status = 'جاري قياس سرعة التحميل...');
    _downloadMbps = await _measureDownload();
    if (!mounted) return;

    setState(() => _status = 'جاري قياس سرعة الرفع...');
    _uploadMbps = await _measureUpload();
    if (!mounted) return;

    _spinController.stop();
    _gaugeController.forward();

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _done = true;
      _status = 'اكتمل الفحص';
    });
  }

  Future<int> _measurePing() async {
    int total = 0;
    int successes = 0;
    final urls = [
      AppConstants.defaultLoginUrl,
      AppConstants.defaultRestUrl,
    ];

    for (int i = 0; i < 4; i++) {
      final url = urls[i % urls.length];
      try {
        final sw = Stopwatch()..start();
        await http.head(Uri.parse(url)).timeout(const Duration(seconds: 3));
        sw.stop();
        total += sw.elapsedMilliseconds;
        successes++;
      } catch (_) {}
    }

    return successes > 0 ? (total ~/ successes) : 999;
  }

  Future<double> _measureDownload() async {
    double totalMbps = 0;
    int tests = 0;
    final urls = [
      AppConstants.defaultRestUrl,
      AppConstants.defaultLiveUrl,
    ];

    for (int i = 0; i < 3; i++) {
      final url = urls[i % urls.length];
      try {
        final sw = Stopwatch()..start();
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 8));
        sw.stop();
        final elapsed = sw.elapsedMilliseconds / 1000.0;
        final bytes = response.bodyBytes.length;
        if (elapsed > 0 && bytes > 0) {
          totalMbps += (bytes * 8) / (elapsed * 1_000_000);
          tests++;
        }
      } catch (_) {}
    }

    return tests > 0 ? totalMbps / tests : 0;
  }

  Future<double> _measureUpload() async {
    final data = List<int>.generate(100000, (_) => Random().nextInt(256));
    double totalMbps = 0;
    int tests = 0;

    for (int i = 0; i < 2; i++) {
      try {
        final sw = Stopwatch()..start();
        await http
            .post(
              Uri.parse(AppConstants.defaultRestUrl),
              body: data,
            )
            .timeout(const Duration(seconds: 8));
        sw.stop();
        final elapsed = sw.elapsedMilliseconds / 1000.0;
        if (elapsed > 0) {
          totalMbps += (data.length * 8) / (elapsed * 1_000_000);
          tests++;
        }
      } catch (_) {}
    }

    return tests > 0 ? totalMbps / tests : 0;
  }

  String _formatSpeed(double mbps) {
    if (mbps >= 100) return (mbps / 100).toStringAsFixed(1);
    if (mbps >= 1) return mbps.toStringAsFixed(1);
    final kbps = mbps * 1000;
    return kbps.toStringAsFixed(0);
  }

  String _speedUnit(double mbps) {
    if (mbps >= 100) return 'ميجابت/ث';
    if (mbps >= 1) return 'ميجابت/ث';
    return 'كيلوبت/ث';
  }

  Color _speedColor(double mbps) {
    if (mbps >= 50) return AppTheme.success;
    if (mbps >= 10) return AppTheme.accent;
    if (mbps >= 1) return AppTheme.accentGold;
    return AppTheme.error;
  }

  Color _pingColor(int ms) {
    if (ms < 30) return AppTheme.success;
    if (ms < 80) return AppTheme.accent;
    if (ms < 200) return AppTheme.accentGold;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('فحص السرعة', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1B2A), Color(0xFF0F1923)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildSpeedGauge(),
                const SizedBox(height: 28),
                _buildResultRow('سرعة التحميل', _downloadMbps, _speedColor(_downloadMbps), Icons.arrow_downward_rounded),
                const SizedBox(height: 12),
                _buildResultRow('سرعة الرفع', _uploadMbps, _speedColor(_uploadMbps), Icons.arrow_upward_rounded),
                const SizedBox(height: 12),
                _buildPingRow(),
                const SizedBox(height: 28),
                _buildActionButton(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedGauge() {
    return AnimatedBuilder(
      animation: Listenable.merge([_spinController, _gaugeAnim]),
      builder: (context, _) {
        final pulse = _isTesting ? 1.0 + sin(_spinController.value * pi * 2) * 0.04 : 1.0;
        return Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 200 * pulse,
                  height: 200 * pulse,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        if (_done) ...[
                          _speedColor(_downloadMbps).withValues(alpha: 0.3),
                          _speedColor(_downloadMbps).withValues(alpha: 0.6),
                          _speedColor(_downloadMbps).withValues(alpha: 0.9),
                          _speedColor(_downloadMbps),
                          _speedColor(_downloadMbps).withValues(alpha: 0.3),
                        ] else if (_isTesting) ...[
                          AppTheme.accent.withValues(alpha: 0.3),
                          AppTheme.accentGold.withValues(alpha: 0.6),
                          AppTheme.accentOrange.withValues(alpha: 0.9),
                          AppTheme.accent.withValues(alpha: 0.3),
                        ] else ...[
                          AppTheme.textMuted.withValues(alpha: 0.2),
                          AppTheme.textMuted.withValues(alpha: 0.4),
                          AppTheme.textMuted.withValues(alpha: 0.2),
                        ],
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_done ? _speedColor(_downloadMbps) : AppTheme.accent)
                            .withValues(alpha: _isTesting ? 0.2 : 0.1),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.surfaceDark,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Center(
                        child: _isTesting
                            ? SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _done ? _formatSpeed(_downloadMbps) : '0',
                                    style: TextStyle(
                                      fontSize: _done && _downloadMbps >= 100 ? 28 : 36,
                                      fontWeight: FontWeight.bold,
                                      color: _done ? _speedColor(_downloadMbps) : AppTheme.textMuted,
                                    ),
                                  ),
                                  Text(
                                    _done ? _speedUnit(_downloadMbps) : '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _done ? _speedColor(_downloadMbps).withValues(alpha: 0.7) : AppTheme.textMuted,
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
            const SizedBox(height: 14),
            Text(
              _status,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _done
                    ? (_downloadMbps > 10 ? AppTheme.success : AppTheme.accentGold)
                    : _isTesting
                        ? AppTheme.accent
                        : AppTheme.textMuted,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResultRow(String label, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          ),
          if (_isTesting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white24)),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _done ? _formatSpeed(value) : '--',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _done ? color : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    _done ? _speedUnit(value) : '',
                    style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPingRow() {
    final color = _done ? _pingColor(_pingMs) : AppTheme.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.hourglass_bottom_rounded, color: AppTheme.textSecondary, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text('زمن الاستجابة (Ping)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          ),
          if (_isTesting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white24)),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _done ? '$_pingMs' : '--',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _done ? color : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    _done ? 'مللي ثانية' : '',
                    style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isTesting ? null : _startTest,
        style: ElevatedButton.styleFrom(
          backgroundColor: _done
              ? (_downloadMbps > 10 ? AppTheme.success : AppTheme.accentGold)
              : AppTheme.accent,
          disabledBackgroundColor: AppTheme.accent.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          shadowColor: (_done ? AppTheme.success : AppTheme.accent).withValues(alpha: 0.3),
        ),
        child: Text(
          _isTesting ? 'جارٍ الفحص...' : (_done ? 'فحص مرة أخرى' : 'ابدأ فحص السرعة'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
