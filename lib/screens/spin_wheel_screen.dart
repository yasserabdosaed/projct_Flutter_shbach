import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/app_provider.dart';
import '../models/spin_prize.dart';

class SpinWheelScreen extends StatefulWidget {
  const SpinWheelScreen({super.key});

  @override
  State<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends State<SpinWheelScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  late Animation<double> _spinAnimation;
  bool _isSpinning = false;
  SpinPrize? _wonPrize;
  String? _drawnCard; // الكرت الحقيقي المسحوب من مخزون الصنف الفائز
  bool _noCardsAvailable = false;
  bool _wheelAvailable = false;
  List<SpinPrize> _currentPrizes = [];
  int _selectedTab = 0; // 0: صغيرة, 1: كبيرة
  int _spinCounter = 0;
  bool _wheelSpun = false; // منع التدوير أكثر من مرة
  bool _copied = false;
  static const int _targetCount = 5;

  // ===== لوحة ألوان متنوعة وهادئة =====
  final List<Color> _prizeColors = [
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFFAB47BC),
    Color(0xFFEF6C00),
    Color(0xFF42A5F5),
    Color(0xFF66BB6A),
    Color(0xFFEC407A),
    Color(0xFF8D6E63),
    Color(0xFF26C6DA),
    Color(0xFF7E57C2),
    Color(0xFFFFA726),
    Color(0xFF78909C),
  ];

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _spinAnimation = Tween<double>(begin: 0, end: 4 * pi).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.easeOutCubic),
    );
    _spinController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finalizeSpin();
      }
    });
  }

  // عند اكتمال دوران العجلة: نختار صنفاً (وزنياً) ثم نسحب كرتاً حقيقياً
  // من مخزونه. إذا المخزون فارغ نعاود اختيار صنف آخر متاح.
  Future<void> _finalizeSpin() async {
    final provider = context.read<AppProvider>();
    String? drawn;
    SpinPrize? chosen;

    for (int attempt = 0; attempt < _currentPrizes.length + 1; attempt++) {
      chosen = _getRandomPrize();
      // اطلب السحب الذري من Firebase
      drawn = await provider.drawPrizeCard(chosen.id);
      if (drawn != null) break;
      // هذا الصنف فرغ مخزونه أو تعذّر الاتصال؛ جرّب صنفاً آخر
    }

    // ===== حماية صارمة ضد الغش/النصب =====
    // بمجرد استلام كرت حقيقي فعلياً (سحب ذرّي أُزيل من المخزون) تُستهلك
    // الدوّارة فوراً ويعود عدّادها إلى الصفر — حتى لو أُغلق التطبيق بعدها
    // أو لم ينسخ المستخدم الكرت. فلا يمكن تدويرها ثانيةً دون شراء 5 كروت جديدة.
    if (drawn != null) {
      final category = _selectedTab == 0 ? 'small' : 'large';
      await provider.resetSpinWheel(category: category);
    }

    if (!mounted) return;
    setState(() {
      _isSpinning = false;
      _wheelSpun = true;
      if (drawn != null) {
        _wonPrize = chosen;
        _drawnCard = drawn;
        _noCardsAvailable = false;
      } else {
        // المخزون فارغ في كل الأصناف أو فشل الاتصال بالسحاب
        _wonPrize = null;
        _drawnCard = null;
        _noCardsAvailable = true;
      }
    });
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  SpinPrize _getRandomPrize() {
    if (_currentPrizes.isEmpty) {
      return SpinPrize(id: '0', name: 'لا توجد جوائز', value: '', type: 'small');
    }

    // وزن جائزة عادية = حسب قيمتها (الجوائز الأكبر قيمةً احتمالية فوزها أقل).
    double weightOf(SpinPrize p) {
      final value = double.tryParse(p.value) ?? 0;
      if (value <= 0) return 1.0; // جوائز بدون قيمة (مثل هدايا عينية) وزن متوسط
      return _weightForValue(value);
    }

    // جائزة الـ1 جيجا (1000 أو 1024 ميجا): احتمال فوز ثابت ~20% من إجمالي
    // السحبات، مهما اختلفت بقية الجوائز (وزنها = 25% من مجموع أوزان البقية،
    // أي 25/125 = 20% من الكل).
    final gigs = _currentPrizes.where(_isOneGigPrize).toList();
    final others = _currentPrizes.where((p) => !gigs.contains(p)).toList();

    if (gigs.isNotEmpty && others.isNotEmpty) {
      final othersWeight = others.fold(0.0, (s, p) => s + weightOf(p));
      final gigWeightPer = (othersWeight * 0.25) / gigs.length;

      final entries = <(SpinPrize, double)>[
        for (final g in gigs) (g, gigWeightPer),
        for (final o in others) (o, weightOf(o)),
      ];
      final total = entries.fold<double>(0, (s, e) => s + e.$2);
      var roll = Random().nextDouble() * total;
      for (final (prize, w) in entries) {
        roll -= w;
        if (roll <= 0) return prize;
      }
      return entries.last.$1;
    }

    // بدون جائزة 1 جيجا (أو كانت كلها 1 جيجا): الاختيار الموزون العادي.
    final weights = _currentPrizes.map(weightOf).toList();

    final totalWeight = weights.fold(0.0, (sum, w) => sum + w);
    if (totalWeight <= 0) {
      final random = Random();
      return _currentPrizes[random.nextInt(_currentPrizes.length)];
    }

    var roll = Random().nextDouble() * totalWeight;
    for (int i = 0; i < _currentPrizes.length; i++) {
      roll -= weights[i];
      if (roll <= 0) {
        return _currentPrizes[i];
      }
    }
    return _currentPrizes.last;
  }

  /// هل هذه الجائزة هي «1 جيجا»؟ تُخزَّن أحياناً 1000 وأحياناً 1024.
  bool _isOneGigPrize(SpinPrize p) {
    final value = double.tryParse(p.value) ?? 0;
    return value == 1000 || value == 1024;
  }

  /// يحسب احتمال (وزن) جائزة حسب قيمتها بالميجابايت.
  /// كلما زادت القيمة، قلّت النسبة/الوزن. الجوائز الكبيرة (7000+) تصبح نادرة
  /// جداً لكنها تبقى ممكنة، والجوائز الصغيرة تبقى الأسهل.
  double _weightForValue(double mb) {
    if (mb <= 0) return 1.0;
    // الجوائز الكبيرة جداً (7 جيجا و 10 جيجا): نادرة للغاية - وزنها يُقسَّم على 100
    // فيصبح احتمال الفوز بأيٍّ منهما أقل من 1% تقريباً (تعتبر جائزة كبرى).
    if (mb >= 7000) return (100.0 / (mb + 50.0)) / 100.0;
    // أمثلة تقريبية على نسب الفوز مع مجموعة كبيرة (1500, 3000, 7000, 10240):
    //   1500 ميجا  ~ 30%
    //   3000 ميجا  ~ 16%
    //   7000 ميجا  ~ 0.15%
    //   10240 ميجا ~ 0.10%
    // الأمثلة أدنى مع مجموعة صغيرة (300, 600):
    //   300 ميجا  ~ 52%  (الأسهل)
    //   600 ميجا  ~ 28%
    // أما الـ1 جيجا (1000/1024) فله نسبة ثابتة ~20% تُحسب في _getRandomPrize.
    return 100.0 / (mb + 50.0);
  }

  void _spin() {
    if (_isSpinning || !_wheelAvailable || _wheelSpun || _currentPrizes.isEmpty) return;
    setState(() {
      _isSpinning = true;
      _wonPrize = null;
      _drawnCard = null;
      _noCardsAvailable = false;
      _copied = false;
    });
    final random = Random().nextDouble() * 2 * pi;
    _spinController.reset();
    _spinController.forward(from: random);
  }

  void _copyAndFinish() {
    // في حالة نفاد المخزون لم يُستلم أي كرت: تبقى الدوّارة محفوظة كما هي
    // (الدرجة 5 والفتح) ليُعاد السحب لاحقاً عندما يتوفر مخزون.
    if (_wonPrize == null && _noCardsAvailable) {
      if (mounted) Navigator.pop(context);
      return;
    }
    if (_wonPrize == null) return;
    // ننسخ الكرت الحقيقي المسحوب من المخزون
    final cardToCopy = _drawnCard ?? _wonPrize!.value;
    if (cardToCopy.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: cardToCopy));
    }
    setState(() => _copied = true);

    // ضمانة إضافية (آمنة حتى لو أُعيدت الضبط سابقاً عند السحب): العجلة تعود
    // من البداية عند الفوز والنسخ في الدوّارتين الصغيرة والكبيرة.
    final provider = context.read<AppProvider>();
    final category = _selectedTab == 0 ? 'small' : 'large';
    provider.resetSpinWheel(category: category);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cardToCopy.isNotEmpty
            ? '✅ تم نسخ الكرت: $cardToCopy'
            : '✅ تم استلام الجائزة'),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) Navigator.pop(context);
    });
  }

  void _loadPrizes(String category) {
    final provider = context.read<AppProvider>();
    final allPrizes = provider.spinPrizes;
    if (category == 'small') {
      _currentPrizes = allPrizes.where((p) => p.type == 'small').toList();
    } else {
      _currentPrizes = allPrizes.where((p) => p.type == 'large').toList();
    }
    if (_currentPrizes.isEmpty) {
      _currentPrizes = category == 'small'
          ? [
              SpinPrize(id: '1', name: '300 ميجا', value: '300', type: 'small'),
              SpinPrize(id: '2', name: '600 ميجا', value: '600', type: 'small'),
              SpinPrize(id: '3', name: '1 جيجا', value: '1024', type: 'small'),
            ]
          : [
              SpinPrize(id: '4', name: '1500 ميجا', value: '1500', type: 'large'),
              SpinPrize(id: '5', name: '3 جيجا', value: '3072', type: 'large'),
              SpinPrize(id: '6', name: '7 جيجا', value: '7168', type: 'large'),
              SpinPrize(id: '7', name: '10 جيجا', value: '10240', type: 'large'),
            ];
    }
    setState(() {});
  }

  Color _getPrizeColor(int index, int total) {
    final colorIndex = index % _prizeColors.length;
    final baseColor = _prizeColors[colorIndex];
    final brightness = 0.85 + (index / total) * 0.15;
    return baseColor.withValues(alpha: brightness);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (_selectedTab == 0) {
      _spinCounter = provider.spinSmallCounter;
      _wheelAvailable = provider.spinSmallAvailable;
    } else {
      _spinCounter = provider.spinLargeCounter;
      _wheelAvailable = provider.spinLargeAvailable;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final category = _selectedTab == 0 ? 'small' : 'large';
      _loadPrizes(category);
    });

    final screenSize = MediaQuery.of(context).size;
    final wheelSize = screenSize.width * 0.72;
    final isSmallScreen = screenSize.width < 360;
    final progress = _spinCounter / _targetCount;
    final hasResult = _wonPrize != null || _noCardsAvailable;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('🎰 عجلة الحظ', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.accent),
          onPressed: () {
            if (!_isSpinning && !hasResult) {
              if (_wheelAvailable && !_wheelSpun) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.cardDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    title: const Text('تنبيه', style: TextStyle(color: Colors.white)),
                    content: const Text('لديك فرصة سحب متاحة! هل تريد الخروج وفقدانها؟', style: TextStyle(color: AppTheme.textSecondary)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء', style: TextStyle(color: AppTheme.textMuted)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context);
                        },
                        child: const Text('خروج', style: TextStyle(color: AppTheme.error)),
                      ),
                    ],
                  ),
                );
              } else {
                Navigator.pop(context);
              }
            }
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A1628),
              Color(0xFF0F1F3A),
              Color(0xFF0A1628),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                if (!hasResult) ...[
                  _buildProgressBar(progress, isSmallScreen),
                  const SizedBox(height: 12),
                  _buildTabs(isSmallScreen),
                  const SizedBox(height: 12),
                  _buildStatusBar(isSmallScreen),
                  const SizedBox(height: 16),
                ],
                Expanded(
                  child: Center(
                    child: _wonPrize != null
                        ? _buildResultView(wheelSize, isSmallScreen)
                        : _noCardsAvailable
                            ? _buildEmptyView(isSmallScreen)
                            : _buildWheel(wheelSize, isSmallScreen),
                  ),
                ),
                if (!hasResult) const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWheel(double wheelSize, bool isSmallScreen) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _spinAnimation,
          builder: (context, child) {
            final total = _currentPrizes.length;
            return Transform.rotate(
              angle: _spinAnimation.value,
              child: Container(
                width: wheelSize,
                height: wheelSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: List.generate(total, (index) {
                      return _getPrizeColor(index, total);
                    }),
                    stops: List.generate(total, (index) {
                      return (index + 1) / total;
                    }),
                  ),
                  border: Border.all(
                    color: _selectedTab == 0
                        ? Color(0xFF7986CB).withValues(alpha: 0.5)
                        : Color(0xFF4DB6AC).withValues(alpha: 0.5),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_selectedTab == 0
                              ? Color(0xFF7986CB)
                              : Color(0xFF4DB6AC))
                          .withValues(alpha: 0.15),
                      blurRadius: 30,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: WheelPainter(
                    prizes: _currentPrizes.map((p) => p.name).toList(),
                    fontSize: isSmallScreen ? 11 : 13,
                    colors: List.generate(total, (index) {
                      return _getPrizeColor(index, total);
                    }),
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(
          top: -10,
          child: Icon(
            Icons.arrow_drop_up_rounded,
            color: _selectedTab == 0 ? Color(0xFF7986CB) : Color(0xFF4DB6AC),
            size: 36,
          ),
        ),
        GestureDetector(
          onTap: _wheelAvailable && !_wheelSpun ? _spin : null,
          child: Container(
            width: wheelSize * 0.2,
            height: wheelSize * 0.2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _wheelAvailable && !_wheelSpun
                    ? [Color(0xFF5C6BC0), Color(0xFF4DB6AC)]
                    : [Colors.grey.shade700, Colors.grey.shade500],
              ),
              boxShadow: [
                BoxShadow(
                  color: (_wheelAvailable && !_wheelSpun
                          ? Color(0xFF5C6BC0)
                          : Colors.grey)
                      .withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Icon(
              _isSpinning
                  ? Icons.hourglass_empty_rounded
                  : Icons.play_arrow_rounded,
              color: Colors.white,
              size: wheelSize * 0.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyView(bool isSmallScreen) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_rounded,
              color: AppTheme.error, size: 80),
          const SizedBox(height: 16),
          const Text(
            'عذراً، نفدت الكروت من المخزون',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'لا توجد كروت متبقية حالياً في المخزون.\nلا تقلق: درجتك محفوظة والدوّارة ستبقى كما هي،\nويمكنك المحاولة من جديد لاحقاً.',
            style: TextStyle(fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _copyAndFinish,
              icon: const Icon(Icons.close_rounded),
              label: const Text('إغلاق'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(double wheelSize, bool isSmallScreen) {
    final prize = _wonPrize!;
    final displayCard = _drawnCard ?? prize.value;
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events_rounded,
              color: Color(0xFFFFD700), size: wheelSize * 0.25),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            decoration: BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Color(0xFFFFD700).withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFFFFD700).withValues(alpha: 0.1),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'تهانينا! 🎉',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: isSmallScreen ? 22 : 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  prize.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 18 : 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (displayCard.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'رمز تسجيل الدخول للكرت:',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: Color(0xFF2A2A3E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Color(0xFFFFD700).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        displayCard,
                        style: TextStyle(
                          color: Color(0xFF4DB6AC),
                          fontSize: isSmallScreen ? 18 : 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _copied ? null : _copyAndFinish,
              icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded),
              label: Text(_copied ? 'تم النسخ!' : displayCard.isNotEmpty
                  ? 'نسخ الكرت'
                  : 'تم'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _copied
                    ? Color(0xFF4DB6AC).withValues(alpha: 0.3)
                    : Color(0xFF4DB6AC),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Color(0xFF4DB6AC).withValues(alpha: 0.3),
                disabledForegroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: TextStyle(
                  fontSize: isSmallScreen ? 15 : 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double progress, bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'التقدم نحو العجلة',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: isSmallScreen ? 13 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$_spinCounter / $_targetCount',
                style: TextStyle(
                  color: _wheelAvailable ? Color(0xFF4DB6AC) : AppTheme.textMuted,
                  fontSize: isSmallScreen ? 13 : 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              color: _wheelAvailable ? Color(0xFF4DB6AC) : Color(0xFF5C6BC0),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          _buildTabButton(0, '⭐ صغيرة', Color(0xFF7986CB), isSmallScreen),
          _buildTabButton(1, '🏆 كبيرة', Color(0xFF4DB6AC), isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, Color color, bool isSmallScreen) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_isSpinning || _wheelSpun) return;
          setState(() {
            _selectedTab = index;
            final category = index == 0 ? 'small' : 'large';
            context.read<AppProvider>().setSpinCategory(category);
            _loadPrizes(category);
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? color : AppTheme.textMuted,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: isSmallScreen ? 12 : 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar(bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _wheelAvailable
            ? Color(0xFF4DB6AC).withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _wheelAvailable
              ? Color(0xFF4DB6AC).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _wheelAvailable ? Icons.check_circle_rounded : Icons.lock_rounded,
            color: _wheelAvailable ? Color(0xFF4DB6AC) : AppTheme.textMuted,
            size: 18,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _wheelAvailable
                  ? '✨ اضغط على العجلة للدوران'
                  : '🔒 قم بشراء $_targetCount كروت لتفعيل العجلة',
              style: TextStyle(
                color: _wheelAvailable ? Color(0xFF4DB6AC) : AppTheme.textMuted,
                fontSize: isSmallScreen ? 12 : 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ===== رسم العجلة (مع ألوان مختلفة لكل قطعة) =====
class WheelPainter extends CustomPainter {
  final List<String> prizes;
  final double fontSize;
  final List<Color> colors;

  WheelPainter({
    required this.prizes,
    this.fontSize = 13,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.9;
    final anglePerPrize = 2 * pi / prizes.length;

    for (int i = 0; i < prizes.length; i++) {
      final startAngle = i * anglePerPrize - pi / 2;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          anglePerPrize,
          false,
        )
        ..close();

      // استخدام اللون المخصص لهذه القطعة
      final color = colors[i % colors.length];
      final paint = Paint()..color = color;
      canvas.drawPath(path, paint);

      // حدود بين القطع
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // رسم النص في منتصف القطعة
      final textAngle = startAngle + anglePerPrize / 2;
      final textRadius = radius * 0.65;
      final textOffset = Offset(
        center.dx + textRadius * cos(textAngle),
        center.dy + textRadius * sin(textAngle),
      );
      final textSpan = TextSpan(
        text: prizes[i],
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(color: Colors.black45, blurRadius: 3)],
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.rtl,
      )..layout();
      final textOffsetAdjusted = Offset(
        textOffset.dx - textPainter.width / 2,
        textOffset.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, textOffsetAdjusted);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}