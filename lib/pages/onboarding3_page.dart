import 'package:flutter/material.dart';
import 'package:ai_interview/config/app_icons.dart';
import 'package:ai_interview/pages/onboarding1_page.dart';
import 'package:ai_interview/pages/onboarding2_page.dart';
import 'package:ai_interview/pages/login_page.dart';

class OnboardingProgressPage extends StatelessWidget {
  const OnboardingProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(AppIcons.icOnboarding3),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const Text(
                  'Track Your Progress',
                  style: TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 40,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 16),

                // Description
                const Text(
                  'Monitor your improvement over time and build confidence '
                  'for the real interview',
                  style: TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 14,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 28),

                // Page indicator (3rd active)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Dot(
                      active: false,
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OnboardingPage(),
                          ),
                        );
                      },
                    ),
                    _Dot(
                      active: false,
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const OnboardingFeedbackPage(),
                          ),
                        );
                      },
                    ),
                    _Dot(active: true, onTap: () {}),
                  ],
                ),

                const SizedBox(height: 28),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          side: const BorderSide(color: Color(0xFF1E83FF)),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            color: Color(0xFF1E83FF),
                            fontSize: 16,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E83FF),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Next',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Dot widget
class _Dot extends StatelessWidget {
  final bool active;
  final VoidCallback? onTap;
  const _Dot({required this.active, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1E83FF) : const Color(0xFFD1D5DB),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
