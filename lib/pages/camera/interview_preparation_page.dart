import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ai_interview/pages/interview_session_page.dart';
import 'package:ai_interview/services/interview_service.dart';
import 'package:ai_interview/services/user_service.dart';

class InterviewPreparationPage extends StatefulWidget {
  final String sessionLength;

  const InterviewPreparationPage({super.key, required this.sessionLength});

  @override
  State<InterviewPreparationPage> createState() =>
      _InterviewPreparationPageState();
}

class _InterviewPreparationPageState extends State<InterviewPreparationPage>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0; // 0 to 3
  bool _isSessionReady = false;
  Map<String, dynamic>? _sessionData;
  Timer? _animationTimer;

  final List<Map<String, String>> _steps = [
    {
      'title': 'Preparing Your Interview',
      'subtitle': 'This should only take a moment',
      'button': 'Start',
    },
    {
      'title': 'Preparing Your Interview',
      'subtitle': 'Setting up your questions',
      'button': 'Start',
    },
    {
      'title': 'Preparing Your Interview',
      'subtitle': 'Optimizing camera & voice analysis',
      'button': 'Start',
    },
    {
      'title': 'Your interview is ready!',
      'subtitle': 'Everything is set',
      'button': 'Start',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAnimationSequence();
    _startSessionCreation();
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  void _startAnimationSequence() {
    // Animate through first 3 steps (0, 1, 2) every 2 seconds
    _animationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_currentStep < 2) {
        if (mounted) {
          setState(() => _currentStep++);
        }
      } else {
        timer
            .cancel(); // Stop at step 2. We only move to step 3 when API finishes
        _checkCompletion();
      }
    });
  }

  Future<void> _startSessionCreation() async {
    try {
      final profile = await UserService.getProfile();
      final targetRole = profile?['target_role'] ?? 'Software Engineer';
      final expLevel = profile?['experience_level'] ?? 'Junior';

      final res = await InterviewService.startSession(
        jobPosition: targetRole,
        experienceLevel: expLevel,
        lengthType: widget.sessionLength,
      );

      if (mounted) {
        if (res['success'] == true) {
          _sessionData = res;
          _isSessionReady = true;
          _checkCompletion();
        } else {
          // If it fails, show error and pop back
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Failed to start session'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _checkCompletion() {
    // If we've animated up to step 2 AND session is ready, move to final step 3 (Checkmark)
    if (_currentStep == 2 && _isSessionReady && mounted) {
      setState(() {
        _currentStep = 3;
      });
    }
  }

  void _onStartPressed() {
    if (_currentStep == 3 && _sessionData != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => InterviewSessionPage(
            sessionId: _sessionData!['session_id'],
            questions: _sessionData!['questions'],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepConfig = _steps[_currentStep];
    final isFinalStep = _currentStep == 3;
    final progressValue =
        (_currentStep / 3).clamp(0.01, 1.0); // 0.01 starts the circle empty

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Back button handling if not completed yet
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: !isFinalStep
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: () {
                          // Allow user to cancel before it finishes
                          Navigator.pop(context);
                        },
                      )
                    : const SizedBox(height: 48), // Spacer
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Dynamic Circular Progress / Checkmark
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: isFinalStep
                          ? Container(
                              key: const ValueKey('checkmark'),
                              width: 100,
                              height: 100,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1E83FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 50,
                              ),
                            )
                          : Stack(
                              key: const ValueKey('progress'),
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: CircularProgressIndicator(
                                    value: progressValue.toDouble(),
                                    backgroundColor:
                                        Colors.blue.withOpacity(0.1),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                      Color(0xFF1E83FF),
                                    ),
                                    strokeWidth: 8,
                                    strokeCap: StrokeCap.round,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 40),
                    // Animated Texts
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Column(
                        key: ValueKey<int>(_currentStep),
                        children: [
                          Text(
                            stepConfig['title']!,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            stepConfig['subtitle']!,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Start Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 200,
                height: 50,
                decoration: BoxDecoration(
                  color:
                      isFinalStep ? const Color(0xFF1E83FF) : Colors.grey[400],
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: isFinalStep
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1E83FF).withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: ElevatedButton(
                  onPressed: isFinalStep ? _onStartPressed : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    stepConfig['button']!,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isFinalStep ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
