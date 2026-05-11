import 'package:flutter/material.dart';
import 'package:ai_interview/config/app_routes.dart';
import 'package:ai_interview/styles/app_colors.dart';
import 'package:ai_interview/styles/app_text.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        fontFamily: 'Urbanist',
        scaffoldBackgroundColor: AppColors.background,
        brightness: Brightness.dark,
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _SmoothPageTransitionBuilder(),
            TargetPlatform.iOS: _SmoothPageTransitionBuilder(),
            TargetPlatform.windows: _SmoothPageTransitionBuilder(),
          },
        ),
        extensions: [
          const AppTextTheme.fallback(),
        ],
      ),
      initialRoute: '/',
      routes: AppRoutes.pages,
    );
  }
}

class _SmoothPageTransitionBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.08, 0.0),
        end: Offset.zero,
      ).animate(curvedAnimation),
      child: FadeTransition(
        opacity: curvedAnimation,
        child: child,
      ),
    );
  }
}
