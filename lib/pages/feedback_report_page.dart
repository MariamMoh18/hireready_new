import 'package:flutter/material.dart';
import 'package:ai_interview/services/interview_service.dart';

class FeedbackReportPage extends StatefulWidget {
  final int sessionId;

  const FeedbackReportPage({super.key, required this.sessionId});

  @override
  State<FeedbackReportPage> createState() => _FeedbackReportPageState();
}

class _FeedbackReportPageState extends State<FeedbackReportPage> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _feedbackData;

  @override
  void initState() {
    super.initState();
    _fetchFeedback();
  }

  Future<void> _fetchFeedback() async {
    final result = await InterviewService.generateFeedback(widget.sessionId);
    if (result['success'] == true) {
      setState(() {
        _feedbackData = result['feedback'];
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Failed to load feedback';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFE2E6EE),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1E83FF)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFE2E6EE),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 18, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchFeedback,
                child: const Text('Retry'),
              )
            ],
          ),
        ),
      );
    }

    final data = _feedbackData ?? {};
    final overallScore = data['overall_score'] ?? 0;
    final strengths = List<String>.from(data['strengths'] ?? []);
    final weaknesses = List<String>.from(data['weaknesses'] ?? []);
    final tips = List<String>.from(data['action_plan'] ?? []);

    return Scaffold(
      backgroundColor: const Color(0xFFE2E6EE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF4B5563), size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: const Text(
          'Interview Feedback',
          style: TextStyle(
            color: Color(0xFF1C1C1E),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Overall Score Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                shadows: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Overall Performance',
                    style: TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: overallScore / 100,
                          strokeWidth: 12,
                          backgroundColor: const Color(0xFFE2E6EE),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF1E83FF),
                          ),
                        ),
                      ),
                      Text(
                        '${overallScore.round()}%',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Strengths
            if (strengths.isNotEmpty)
              _buildFeedbackList(
                  'Strengths', strengths, Icons.check_circle, Colors.green),
            const SizedBox(height: 16),

            // Areas to improve
            if (weaknesses.isNotEmpty)
              _buildFeedbackList('Areas to Improve', weaknesses,
                  Icons.warning_amber_rounded, Colors.orange),
            const SizedBox(height: 16),

            // Actionable Tips
            if (tips.isNotEmpty)
              _buildFeedbackList('Actionable Tips', tips,
                  Icons.lightbulb_outline, Colors.blue),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackList(
      String title, List<String> items, IconData icon, Color iconColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1C1C1E),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4.0),
                      child:
                          Icon(Icons.circle, size: 8, color: Color(0xFF9CA3AF)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: Color(0xFF4B5563),
                          fontSize: 15,
                          height: 1.5,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
