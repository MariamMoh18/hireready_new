import 'package:flutter/material.dart';
import 'package:ai_interview/config/app_icons.dart';
import 'package:ai_interview/config/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  Future<void> _startTimer() async {
    // Wait for 2500ms
    await Future.delayed(const Duration(milliseconds: 2500));
    _goToWelcome();
  }

  void _goToWelcome() {
    if (!mounted || _navigated) return;
    _navigated = true;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => Theme(
            data: Theme.of(context),
            child: AppRoutes.pages[AppRoutes.welcome]!(context)),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = 0.0;
          const end = 1.0;
          const curve = Curves.easeOut;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return FadeTransition(
            opacity: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2F76DD),
      body: GestureDetector(
        onDoubleTap: _goToWelcome,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Container(
            width: 118,
            height: 165,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(AppIcons.icLogo),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
