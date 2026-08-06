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

  const ProfessionalWebView({
    super.key,
    required this.url,
    required this.title,
    this.loadingText = 'جاري التحميل...',
    this.accentColor = AppTheme.accent,
    this.injectMobileViewport = true,
  });

  @override
  State<ProfessionalWebView> createState() => _ProfessionalWebViewState();
}

class _ProfessionalWebViewState extends State<ProfessionalWebView>
    with WidgetsBindingObserver {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initWebView();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _exitFullscreen();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // عند تغيير الاتجاه، نضبط الفيديو مرة أخرى
    if (_isFullscreen) {
      _adjustVideoForFullscreen();
    }
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) async {
            if (mounted) setState(() => _isLoading = false);
            if (widget.injectMobileViewport) {
              await _injectMobileViewport();
            }
            // إذا كان في وضع التكبير، نضبط الفيديو
            if (_isFullscreen) {
              await _adjustVideoForFullscreen();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  // ===== حقن الكود لتوسيط الفيديو =====
  Future<void> _injectMobileViewport() async {
    try {
      await _controller.runJavaScript('''
(function(){
try{
  // ضبط الـ Viewport
  var m=document.querySelector('meta[name="viewport"]');
  if(!m){m=document.createElement('meta');m.name='viewport';document.head.appendChild(m);}
  m.content='width=device-width, initial-scale=1, maximum-scale=1, user-scalable=yes, viewport-fit=cover';
  
  // ضبط الهوامش
  document.body.style.margin='0';
  document.body.style.padding='0';
  document.documentElement.style.margin='0';
  document.documentElement.style.padding='0';
  document.body.style.height='100%';
  document.documentElement.style.height='100%';
  document.body.style.width='100%';
  document.documentElement.style.width='100%';
  document.body.style.overflow='hidden';
  document.documentElement.style.overflow='hidden';
  
  // جعل جميع العناصر تملأ الشاشة
  var allElements = document.querySelectorAll('*');
  allElements.forEach(function(el){
    if(el.style){
      el.style.maxWidth='100%';
      el.style.maxHeight='100%';
      el.style.boxSizing='border-box';
    }
  });
  
  // توسيط المحتوى في منتصف الشاشة
  document.body.style.display='flex';
  document.body.style.alignItems='center';
  document.body.style.justifyContent='center';
  document.body.style.flexDirection='column';
  
  // البحث عن عناصر الفيديو ومشغلات الفيديو
  var videoElements = document.querySelectorAll('video, .video-js, .vjs-tech, iframe, .vjs_video_3-dimensions, .vjs-fluid, .jw-video, .jwplayer, .plyr__video-wrapper');
  videoElements.forEach(function(el){
    el.style.width='100%';
    el.style.height='100%';
    el.style.maxWidth='100%';
    el.style.maxHeight='100%';
    el.style.objectFit='contain';
    el.style.display='block';
    el.style.margin='0 auto';
    // إذا كان العنصر داخل حاوية، نجعل الحاوية أيضاً تملأ الشاشة
    var parent = el.parentElement;
    if(parent){
      parent.style.width='100%';
      parent.style.height='100%';
      parent.style.maxWidth='100%';
      parent.style.maxHeight='100%';
      parent.style.display='flex';
      parent.style.alignItems='center';
      parent.style.justifyContent='center';
    }
  });
  
  // البحث عن أي عنصر يحتوي على فيديو (مثل div مع class video-container)
  var containers = document.querySelectorAll('.video-container, .player-container, .video-wrapper, .vjs-video');
  containers.forEach(function(el){
    el.style.width='100%';
    el.style.height='100%';
    el.style.maxWidth='100%';
    el.style.maxHeight='100%';
    el.style.display='flex';
    el.style.alignItems='center';
    el.style.justifyContent='center';
  });
  
}catch(e){}
})();
''');
    } catch (_) {}
  }

  // ===== ضبط الفيديو عند التكبير =====
  Future<void> _adjustVideoForFullscreen() async {
    try {
      await _controller.runJavaScript('''
(function(){
try{
  // إزالة جميع الهوامش
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
  
  // توسيط المحتوى
  document.body.style.display='flex';
  document.body.style.alignItems='center';
  document.body.style.justifyContent='center';
  document.body.style.flexDirection='column';
  
  // جعل جميع العناصر تملأ الشاشة
  var allElements = document.querySelectorAll('*');
  allElements.forEach(function(el){
    if(el.style){
      el.style.maxWidth='100%';
      el.style.maxHeight='100%';
    }
  });
  
  // البحث عن الفيديو وجعله يملأ الشاشة
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
    // محاولة تشغيل الفيديو بملء الشاشة عبر API
    if(video.requestFullscreen){
      video.requestFullscreen().catch(function(e){});
    } else if(video.webkitRequestFullscreen){
      video.webkitRequestFullscreen().catch(function(e){});
    } else if(video.mozRequestFullScreen){
      video.mozRequestFullScreen().catch(function(e){});
    } else if(video.msRequestFullscreen){
      video.msRequestFullscreen().catch(function(e){});
    }
    // جعل جميع العناصر المحيطة تملأ الشاشة
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
  
  // محاولة العثور على أي عنصر يحتوي على فيديو وجعله يملأ الشاشة
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
      setState(() {
        _isFullscreen = true;
      });
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
      setState(() {
        _isFullscreen = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    setState(() => _isLoading = true);
                    _initWebView();
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
            height: _isFullscreen
                ? constraints.maxHeight
                : constraints.maxHeight,
            color: Colors.black,
            alignment: Alignment.center,
            child: WebViewWidget(
              controller: _controller,
            ),
          );
        },
      ),
    );
  }
}