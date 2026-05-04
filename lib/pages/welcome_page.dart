import 'package:flutter/material.dart';
import 'package:ai_interview/styles/app_colors.dart';
import 'package:ai_interview/config/app_routes.dart';
import 'package:ai_interview/config/app_icons.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Urbanist',
                  fontSize: 24, // Reduced size
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                children: [
                  TextSpan(
                    text: 'Get that\n',
                    style: TextStyle(
                      color: AppColors.getThat /* text-body */,
                      fontSize: 20,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      height: 1.40,
                    ),
                  ),
                  TextSpan(
                    text: 'Dream job',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      foreground: Paint()
                        ..shader = const LinearGradient(
                          colors: [
                            Color(0xFF71D1FF),
                            Color(0xFF1E83FF),
                            Color(0xFF71D1FF),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Main Illustration
            // Main Illustration with Floating Icons
            // Main Illustration
            Expanded(
              child: Image.asset(
                AppIcons.welcome3d,
                width: 331,
                height: 565, // Let expanded handle height
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 27),
            SizedBox(
              width: 292,
              height: 56,
              child: Text(
                'With AI-powered Mock Interview',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF4B5563) /* text-body */,
                  fontSize: 20,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  height: 1.20,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Get Started Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.onboarding1);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF1E83FF), // same as Container
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100), // pill shape
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 14),
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      height: 1.13,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
