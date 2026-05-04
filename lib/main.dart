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
        extensions: [
          const AppTextTheme.fallback(),
        ],
      ),
      initialRoute: '/',
      routes: AppRoutes.pages,
    );
  }
}
