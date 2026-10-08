import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config/theme.dart';

class ProfessionalWebView extends StatefulWidget {
  final String url;
  final String title;
  final String loadingText;
  final Color accentColor;
  final bool injectMobileViewport;
  final String? demoAsset;

  const ProfessionalWebView({
    super.key,
    required this.url,
    required this.title,
    this.loadingText = 'جاري التحميل...',
    this.accentColor = AppTheme.accent,
    this.injectMobileViewport = true,
    this.demoAsset,
  });

  @override
  State<ProfessionalWebView> createState() => _ProfessionalWebViewState();
}

class _ProfessionalWebViewState extends State<ProfessionalWebView>
    with WidgetsBindingObserver {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _isFullscreen = false;
  bool _isDemoMode = false;
  bool _mainFrameFailed = false;
  Timer? _loadTimeout;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initWebView();
    _initialFlow();
  }

  @override
  void dispose() {
    _loadTimeout?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _exitFullscreen();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (_isFullscreen) {
      _adjustVideoForFullscreen();
    }
  }

  Future<void> _initialFlow() async {
    final reachable = await _isNetworkReachable(widget.url);
    if (!mounted) return;
    if (reachable) {
      _loadRealUrl();
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

  void _loadRealUrl() {
    if (!mounted) return;
    _isDemoMode = false;
    _mainFrameFailed = false;
    setState(() => _isLoading = true);
    _loadTimeout?.cancel();
    _controller.loadRequest(Uri.parse(widget.url));
    _startLoadTimeout();
  }

  void _showDemoMode() {
    if (!mounted || widget.demoAsset == null) return;
    _isDemoMode = true;
    _loadTimeout?.cancel();
    setState(() => _isLoading = true);
    _controller.loadFlutterAsset(widget.demoAsset!);
  }

  void _startLoadTimeout() {
    _loadTimeout?.cancel();
    _loadTimeout = Timer(const Duration(seconds: 12), () {
      if (mounted && _isLoading) {
        _mainFrameFailed = true;
        setState(() => _isLoading = false);
      }
    });
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            _mainFrameFailed = false;
            if (mounted) {
              setState(() => _isLoading = true);
            }
            _startLoadTimeout();
          },
          onPageFinished: (_) async {
            _loadTimeout?.cancel();
            if (mounted) {
              setState(() => _isLoading = false);
            }
            if (_mainFrameFailed) return;
            if (!_isDemoMode && widget.injectMobileViewport) {
              await _injectMobileViewport();
            }
            if (_isFullscreen) {
              await _adjustVideoForFullscreen();
            }
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame != true) return;
            _mainFrameFailed = true;
            _loadTimeout?.cancel();
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
        ),
      );
  }

  Future<void> _injectMobileViewport() async {
    try {
      await _controller.runJavaScript('''
(function(){
try{
  var m=document.querySelector('meta[name="viewport"]');
  if(!m){m=document.createElement('meta');m.name='viewport';document.head.appendChild(m);}
  m.content='width=device-width, initial-scale=1, maximum-scale=1, user-scalable=yes, viewport-fit=cover';
  document.documentElement.style.overflow='auto';
  document.documentElement.style.height='auto';
  document.body.style.overflow='auto';
  document.body.style.height='auto';
  document.body.style.margin='0';
  document.body.style.padding='0';
  document.documentElement.style.margin='0';
  document.documentElement.style.padding='0';
  ['img','table','video','iframe','embed'].forEach(function(tag){
    document.querySelectorAll(tag).forEach(function(el){
      el.style.maxWidth='100%';
      el.style.boxSizing='border-box';
    });
  });
  document.querySelectorAll('video, .video-js, .vjs-tech, iframe, .vjs-fluid, .jw-video, .jwplayer, .plyr__video-wrapper').forEach(function(el){
    el.style.maxWidth='100%';
    el.style.objectFit='contain';
    el.style.display='block';
    el.style.margin='0 auto';
  });
}catch(e){}
})();
''');
    } catch (_) {}
  }

  Future<void> _adjustVideoForFullscreen() async {
    try {
      await _controller.runJavaScript('''
(function(){
try{
  document.body.style.margin='0';
  document.body.style.padding='0';
  document.documentElement.style.margin='0';
  document.documentElement.style.padding='0';
  document.body.style.height='100vh';
  document.documentElement.style.height='100vh';
  document.body.style.width='100vw';
  document.documentElement.style.width='100vw';
  document.body.style.overflow='hidden';
  document.documentElement.style.overflow='hidden';
  document.body.style.position='fixed';
  document.body.style.top='0';
  document.body.style.left='0';
  document.body.style.bottom='0';
  document.body.style.right='0';
  document.body.style.display='flex';
  document.body.style.alignItems='center';
  document.body.style.justifyContent='center';
  document.body.style.flexDirection='column';
  var allElements = document.querySelectorAll('*');
  allElements.forEach(function(el){
    if(el.style){
      el.style.maxWidth='100%';
      el.style.maxHeight='100%';
    }
  });
  var video = document.querySelector('video, .video-js, .vjs-tech, iframe, .jw-video, .plyr');
  if(video){
    video.style.width='100vw';
    video.style.height='100vh';
    video.style.maxWidth='100vw';
    video.style.maxHeight='100vh';
    video.style.objectFit='contain';
    video.style.position='absolute';
    video.style.top='0';
    video.style.left='0';
    video.style.display='block';
    video.style.margin='0';
    if(video.requestFullscreen){
      video.requestFullscreen().catch(function(e){});
    } else if(video.webkitRequestFullscreen){
      video.webkitRequestFullscreen().catch(function(e){});
    } else if(video.mozRequestFullScreen){
      video.mozRequestFullScreen().catch(function(e){});
    } else if(video.msRequestFullscreen){
      video.msRequestFullscreen().catch(function(e){});
    }
    var parent = video.parentElement;
    while(parent && parent !== document.body){
      parent.style.width='100vw';
      parent.style.height='100vh';
      parent.style.maxWidth='100vw';
      parent.style.maxHeight='100vh';
      parent.style.display='flex';
      parent.style.alignItems='center';
      parent.style.justifyContent='center';
      parent.style.overflow='hidden';
      parent = parent.parentElement;
    }
  }
  var containers = document.querySelectorAll('.video-container, .player-container, .video-wrapper, .vjs-video, .jwplayer-container');
  containers.forEach(function(el){
    el.style.width='100vw';
    el.style.height='100vh';
    el.style.maxWidth='100vw';
    el.style.maxHeight='100vh';
    el.style.display='flex';
    el.style.alignItems='center';
    el.style.justifyContent='center';
    el.style.overflow='hidden';
    el.style.margin='0';
    el.style.padding='0';
  });
}catch(e){}
})();
''');
    } catch (_) {}
  }

  void _enterFullscreen() async {
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      setState(() => _isFullscreen = true);
      await Future.delayed(const Duration(milliseconds: 300));
      await _adjustVideoForFullscreen();
    } catch (e) {}
  }

  void _exitFullscreen() async {
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      setState(() => _isFullscreen = false);
      await _controller.reload();
    } catch (e) {}
  }

  void _toggleFullscreen() {
    if (_isFullscreen) {
      _exitFullscreen();
    } else {
      _enterFullscreen();
    }
  }

  /// معالجة زر الرجوع:
  /// 1) إذا كان في ملء الشاشة → الخروج من ملء الشاشة أولاً
  /// 2) إذا يمكن للويب فيو الرجوع (مثل من داخل فلم/حلقة) → الرجوع داخل الصفحة
  /// 3) وإلا → الخروج من الشاشة للصفحة الرئيسية
  Future<void> _handleBack() async {
    if (_isFullscreen) {
      _exitFullscreen();
      return;
    }
    try {
      if (await _controller.canGoBack()) {
        await _controller.goBack();
        return;
      }
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      appBar: _isFullscreen
          ? null
          : AppBar(
              backgroundColor: AppTheme.surfaceDark,
              title: Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () {
                    if (_isDemoMode) {
                      _showDemoMode();
                    } else {
                      setState(() => _isLoading = true);
                      _loadRealUrl();
                    }
                  },
                ),
                IconButton(
                  icon: Icon(
                    _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  ),
                  onPressed: _toggleFullscreen,
                ),
              ],
            ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            color: Colors.black,
            alignment: Alignment.center,
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isDemoMode && !_isFullscreen)
                  Positioned(
                    left: 0, right: 0, top: 0,
                    child: Material(
                      color: AppTheme.accentGold.withValues(alpha: 0.95),
                      child: SafeArea(
                        bottom: false,
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
                                onPressed: _loadRealUrl,
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
                  ),
                if (_isLoading && !_isFullscreen)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.black,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: widget.accentColor,
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.loadingText,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }
}
