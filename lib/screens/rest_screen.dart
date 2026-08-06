import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/app_provider.dart';
import '../widgets/professional_webview.dart';

class RestScreen extends StatelessWidget {
  const RestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final url = context.read<AppProvider>().restUrl;
    return ProfessionalWebView(
      url: url,
      title: 'منصة الاستراحة',
      loadingText: 'جاري تحميل منصة الاستراحة...',
      accentColor: AppTheme.accentGold,
    );
  }
}
