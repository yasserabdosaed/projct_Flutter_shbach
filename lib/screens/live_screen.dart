import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/app_provider.dart';
import '../widgets/professional_webview.dart';

class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final url = context.read<AppProvider>().liveUrl;
    return ProfessionalWebView(
      url: url,
      title: 'البث المباشر',
      loadingText: 'جاري تحميل البث المباشر...',
      accentColor: AppTheme.accentOrange,
    );
  }
}
