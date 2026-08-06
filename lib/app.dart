import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'providers/app_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/live_screen.dart';
import 'screens/rest_screen.dart';
import 'screens/speed_test_screen.dart';
import 'screens/spin_wheel_screen.dart';
import 'screens/suggestions_screen.dart';
import 'screens/contact_screen.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_panel_screen.dart';
import 'screens/messages_screen.dart';

class ShabakatApp extends StatelessWidget {
  const ShabakatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return MaterialApp(
          title: 'شبكة الحارث',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          initialRoute: AppRoutes.splash,
          onGenerateRoute: (settings) {
            Widget page;
            switch (settings.name) {
              case AppRoutes.splash:
                page = const SplashScreen();
              case AppRoutes.home:
                page = const HomeScreen();
              case AppRoutes.login:
                page = const LoginScreen();
              case AppRoutes.live:
                page = const LiveScreen();
              case AppRoutes.rest:
                page = const RestScreen();
              case AppRoutes.speedTest:
                page = const SpeedTestScreen();
              case AppRoutes.suggestions:
                page = const SuggestionsScreen();
              case AppRoutes.contact:
                page = const ContactScreen();
              case AppRoutes.adminLogin:
                page = const AdminLoginScreen();
              case AppRoutes.adminPanel:
                page = const AdminPanelScreen();
              case AppRoutes.messages:
                page = const MessagesScreen();
              case AppRoutes.spinWheel:
                page = const SpinWheelScreen();
              default:
                page = const HomeScreen();
            }
            return _buildPageRoute(page, settings);
          },
        );
      },
    );
  }

  PageRouteBuilder _buildPageRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.05);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(animation);

        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }
}