import 'package:flutter/material.dart';
import 'package:ai_interview/config/app_icons.dart';
import 'package:ai_interview/config/app_routes.dart';
import 'package:ai_interview/services/auth_service.dart';
import 'package:ai_interview/services/user_service.dart';

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

    Navigator.pushReplacementNamed(context, AppRoutes.welcome);
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
