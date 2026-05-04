import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ai_interview/config/app_routes.dart';
import 'package:ai_interview/widgets/custom_bottom_nav.dart';
import 'package:ai_interview/services/interview_service.dart';
import 'package:ai_interview/pages/feedback_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await InterviewService.getSessionHistory();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteSession(int sessionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: const Text('Are you sure you want to delete this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deleting session...')),
        );
      }
      final result = await InterviewService.deleteSession(sessionId);
      if (result['success'] == true) {
        _loadSessions();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: ${result['message']}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Count all active/past sessions
    final completedSessions = _sessions;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: _buildAppBar(context),
            ),
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF3B99FC)),
                    )
                  : _sessions.isEmpty
                      ? _buildEmptyState()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              _buildTitleSection(completedSessions.length),
                              const SizedBox(height: 20),
                              ..._sessions
                                  .map((session) => _buildSessionCard(session)),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
            ),
            // Bottom nav
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: CustomBottomNav(activeRoute: AppRoutes.history),
            ),
          ],
        ),
      ),
    );
  }

  // ── App Bar ──────────────────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back button
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
        // Settings button
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
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.settings);
            },
          ),
        ),
      ],
    );
  }

  // ── Title Section ───────────────────────────────────────────────────
  Widget _buildTitleSection(int completedCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Session History',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$completedCount sessions completed',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  // ── Empty State ─────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No sessions yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a practice session to see your history here',
            style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Session Card ────────────────────────────────────────────────────
  Widget _buildSessionCard(Map<String, dynamic> session) {
    // Parse date
    final startTime = session['start_time'] != null
        ? DateTime.tryParse(session['start_time'])
        : null;
    final dateStr = startTime != null
        ? DateFormat('MMM dd, yyyy').format(startTime)
        : 'Unknown date';

    // Type label
    final lengthType = session['length_type'] ?? 'standard';
    final typeLabel = _capitalize(lengthType);

    // Duration
    final durationMinutes = session['duration_minutes'] ?? 0;
    final durationStr = '${durationMinutes}min';

    // Score
    final score = session['overall_score'];
    final scoreInt = score != null ? (score as num).round() : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top row: Date + Type/Duration on left, Score badge on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date and type info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$typeLabel • $durationStr',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
                // Corner icons + badge
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (scoreInt != null) _buildScoreBadge(scoreInt),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 20),
                      onPressed: () => _deleteSession(session['id']),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // View Report button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          FeedbackPage(sessionId: session['id']),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'View Report',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Score Badge ─────────────────────────────────────────────────────
  Widget _buildScoreBadge(int score) {
    Color badgeColor;
    if (score >= 80) {
      badgeColor = const Color(0xFF4ADE80); // green
    } else if (score >= 60) {
      badgeColor = const Color(0xFFFB923C); // orange
    } else {
      badgeColor = const Color(0xFFF87171); // red
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          '$score%',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────
  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
