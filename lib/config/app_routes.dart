import 'package:flutter/material.dart';
import 'package:ai_interview/pages/splash_screen.dart';
import 'package:ai_interview/pages/welcome_page.dart';
import 'package:ai_interview/pages/home_page.dart';
import 'package:ai_interview/pages/login_page.dart';
import 'package:ai_interview/pages/signup_page.dart';
import 'package:ai_interview/pages/profile_page.dart';
import 'package:ai_interview/pages/profileSetup_page.dart';
import 'package:ai_interview/pages/onboarding1_page.dart';
import 'package:ai_interview/pages/onboarding2_page.dart';
import 'package:ai_interview/pages/onboarding3_page.dart';
import 'package:ai_interview/pages/settings_page.dart';
import 'package:ai_interview/pages/progress_page.dart';
import 'package:ai_interview/pages/history_page.dart';

class AppRoutes {
  static final Map<String, Widget Function(BuildContext)> pages = {
    '/': (context) => const SplashScreen(),
    '/welcome': (context) => const WelcomePage(),
    '/onboarding1': (context) => const OnboardingPage(),
    '/onboarding2': (context) => const OnboardingFeedbackPage(),
    '/onboarding3': (context) => const OnboardingProgressPage(),
    '/login': (context) => const LoginPage(),
    '/signup': (context) => const SignUpPage(),
    '/home': (context) => const HomePage(),
    '/main': (context) => const HomePage(),
    '/profile': (context) => const ProfilePage(),
    '/profileSetup': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final name = (args is Map<String, dynamic>) ? args['name'] as String? : null;
      return ProfileSetupPage(initialUsername: name);
    },
    '/settings': (context) => const SettingsPage(),
    '/progress': (context) => const ProgressPage(),
    '/history': (context) => const HistoryPage(),
  };
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String home = '/home';
  static const String onboarding1 = '/onboarding1';
  static const String onboarding2 = '/onboarding2';
  static const String onboarding3 = '/onboarding3';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String main = '/main';
  static const String profile = '/profile';
  static const String profileSetup = '/profileSetup';
  static const String settings = '/settings';
  static const String progress = '/progress';
  static const String history = '/history';
}
