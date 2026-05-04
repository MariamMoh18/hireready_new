import 'dart:math';
import 'package:flutter/material.dart';
import 'package:ai_interview/services/interview_service.dart';

class FeedbackPage extends StatefulWidget {
  final int sessionId;

  const FeedbackPage({super.key, required this.sessionId});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _feedbackData;
  int _selectedQuestion = 0; // index of the selected Q in Response Evaluation

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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF1E83FF)),
              SizedBox(height: 16),
              Text(
                'Generating your feedback...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 18, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _fetchFeedback();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _feedbackData ?? {};
    final overallScore = (data['overall_score'] ?? 0).toDouble();
    final voiceScore = (data['voice_score'] ?? 0).toDouble();
    final facialScore = (data['facial_score'] ?? 0).toDouble();
    final contentScore = (data['content_score'] ?? 0).toDouble();
    final strengths = List<String>.from(data['strengths'] ?? []);
    final weaknesses = List<String>.from(data['weaknesses'] ?? []);
    final suggestions = List<String>.from(data['suggestions'] ?? []);
    final qaPairs = List<Map<String, dynamic>>.from(data['qa_pairs'] ?? []);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF90CAF9), Color(0xFFE3F2FD), Colors.white],
            stops: [0.0, 0.35, 0.6],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: _buildAppBar(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      _buildOverallScore(overallScore),
                      const SizedBox(height: 32),
                      _buildScoreCards(voiceScore, facialScore, contentScore),
                      const SizedBox(height: 28),
                      if (strengths.isNotEmpty)
                        _buildFeedbackCard(
                          title: 'Key Strengths',
                          items: strengths,
                          icon: Icons.check_circle,
                          color: const Color(0xFF4CAF50),
                        ),
                      const SizedBox(height: 20),
                      if (weaknesses.isNotEmpty || suggestions.isNotEmpty)
                        _buildFeedbackCard(
                          title: 'Improvement Suggestions',
                          items:
                              suggestions.isNotEmpty ? suggestions : weaknesses,
                          icon: Icons.lightbulb,
                          color: const Color(0xFFFFA726),
                        ),
                      const SizedBox(height: 28),
                      if (qaPairs.isNotEmpty) _buildResponseEvaluation(qaPairs),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              // Bottom buttons
              _buildBottomButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  // ── App Bar ─────────────────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: Colors.black54),
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.settings_outlined,
                size: 18, color: Color(0xFF4B5563)),
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ),
      ],
    );
  }

  // ── Overall Score ───────────────────────────────────────────────────
  Widget _buildOverallScore(double score) {
    return Center(
      child: SizedBox(
        height: 180,
        width: 180,
        child: CustomPaint(
          painter: _CircularScorePainter(
            score: score,
            strokeWidth: 14,
            backgroundColor: Colors.white.withOpacity(0.3),
            progressColor: const Color(0xFF1E83FF),
          ),
          child: Center(
            child: Text(
              '${score.round()}',
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E83FF),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Three Score Cards ──────────────────────────────────────────────
  Widget _buildScoreCards(
      double voiceScore, double facialScore, double contentScore) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildScoreCard(
          score: voiceScore,
          label: 'Voice\n& Tone',
          color: const Color(0xFF90CAF9),
        ),
        _buildScoreCard(
          score: facialScore,
          label: 'Facial\nExpression',
          color: const Color(0xFF1E83FF),
        ),
        _buildScoreCard(
          score: contentScore,
          label: 'Content\nQuality',
          color: const Color(0xFF1565C0),
        ),
      ],
    );
  }

  Widget _buildScoreCard({
    required double score,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        SizedBox(
          height: 76,
          width: 76,
          child: CustomPaint(
            painter: _CircularScorePainter(
              score: score,
              strokeWidth: 8,
              backgroundColor: Colors.white.withOpacity(0.3),
              progressColor: color,
            ),
            child: Center(
              child: Text(
                '${score.round()}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  // ── Feedback Card (Strengths / Suggestions) ────────────────────────
  Widget _buildFeedbackCard({
    required String title,
    required List<String> items,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with pill badge
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 7, right: 12),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.5,
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

  // ── Response Evaluation ────────────────────────────────────────────
  Widget _buildResponseEvaluation(List<Map<String, dynamic>> qaPairs) {
    final selectedQ = _selectedQuestion < qaPairs.length
        ? qaPairs[_selectedQuestion]
        : qaPairs.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Response evaluation',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question tabs (left side)
            SizedBox(
              width: 48,
              child: Column(
                children: List.generate(qaPairs.length, (i) {
                  final isSelected = i == _selectedQuestion;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedQuestion = i);
                    },
                    child: Container(
                      width: 48,
                      height: 40,
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1E83FF)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Q${i + 1}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.black54,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 12),
            // Q&A content (right side)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Q:${selectedQ['question'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E83FF),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'A: ${selectedQ['answer'] ?? '(No answer)'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Bottom Buttons ─────────────────────────────────────────────────
  Widget _buildBottomButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Report button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: Generate PDF report
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Report generation coming soon!')),
                );
              },
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Report'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E83FF),
                side: const BorderSide(color: Color(0xFF1E83FF)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Practice again button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                // Navigate back to home to start a new interview
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/home', (route) => false);
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Practice again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E83FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom Painter for circular score ──────────────────────────────
class _CircularScorePainter extends CustomPainter {
  final double score;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;

  _CircularScorePainter({
    required this.score,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * pi * (score / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularScorePainter oldDelegate) {
    return oldDelegate.score != score;
  }
}
