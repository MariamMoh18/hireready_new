import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:ai_interview/pages/feedback_page.dart';
import 'package:ai_interview/config/app_routes.dart';
import 'package:ai_interview/services/interview_service.dart';

class InterviewSessionPage extends StatefulWidget {
  final int sessionId;
  final List<dynamic> questions;

  const InterviewSessionPage({
    super.key,
    required this.sessionId,
    required this.questions,
  });

  @override
  State<InterviewSessionPage> createState() => _InterviewSessionPageState();
}

class _InterviewSessionPageState extends State<InterviewSessionPage> {
  // ── Question tracking ──────────────────────────────────────────────
  int _currentQuestion = 1;

  // ── Timer (per-question: 1 min 20 sec = 80 seconds) ────────────────
  static const int _questionDuration = 80; // 1:20
  int _timerSeconds = _questionDuration;
  bool _isRecording = false;
  bool _isUploading = false;
  Timer? _timer;

  // ── Camera ──────────────────────────────────────────────────────────
  CameraController? _cameraController;
  bool _isCameraReady = false;

  // ── Session data ────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _recordedAnswers = [];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  // ── Camera init ────────────────────────────────────────────────────
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      // Prefer front camera
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraReady = true);
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  // ── Timer logic ────────────────────────────────────────────────────
  void _startTimer() {
    _timer?.cancel();
    _timerSeconds = _questionDuration;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
      } else {
        timer.cancel();
        _stopRecordingAndUpload();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  void _advanceToNextQuestion() {
    if (_currentQuestion < widget.questions.length) {
      setState(() {
        _currentQuestion++;
        _isRecording = false;
        _timerSeconds = _questionDuration;
      });
      // Auto-start recording for the next question
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _startRecording();
        }
      });
    } else {
      // All questions done → upload everything and navigate
      _timer?.cancel();
      if (mounted) {
        _uploadAllAndEndSession();
      }
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    try {
      await _cameraController!.startVideoRecording();
      if (mounted) {
        setState(() => _isRecording = true);
        _startTimer();
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecordingAndUpload() async {
    if (_cameraController == null || !_cameraController!.value.isRecordingVideo) {
      return;
    }

    _stopTimer();
    setState(() {
      _isRecording = false;
    });

    try {
      final videoFile = await _cameraController!.stopVideoRecording();

      // Get current question ID from AI questions list
      final questionData = widget.questions[_currentQuestion - 1];
      final questionId = questionData['id'] ?? _currentQuestion;

      _recordedAnswers.add({
        'questionId': questionId,
        'videoFile': videoFile,
      });
    } catch (e) {
      debugPrint('Error capturing video: $e');
    } finally {
      if (mounted) {
        _advanceToNextQuestion();
      }
    }
  }

  Future<void> _uploadAllAndEndSession() async {
    setState(() => _isUploading = true);

    try {
      // 1. Upload all answers
      for (var answer in _recordedAnswers) {
        final videoFile = answer['videoFile'] as XFile;
        final questionId = answer['questionId'] as int;

        final res = await InterviewService.uploadVideoAnswer(
          sessionId: widget.sessionId,
          questionId: questionId,
          videoFile: videoFile,
        );

        if (res['success'] != true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Upload failed for Q$questionId: ${res['message']}')),
          );
        }
      }

      // 2. End session to mark it completed
      await InterviewService.endSession(widget.sessionId);
    } catch (e) {
      debugPrint('Error uploading videos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => FeedbackPage(sessionId: widget.sessionId),
          ),
        );
      }
    }
  }

  void _toggleRecording() {
    if (_isRecording) {
      _stopRecordingAndUpload();
    } else {
      _startRecording();
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ── Exit dialog ────────────────────────────────────────────────────
  Future<void> _showExitConfirmation() async {
    _stopTimer();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: 310,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 99,
                  height: 99,
                  decoration: ShapeDecoration(
                    color: const Color(0xFFE05359),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      '!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 60,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 222,
                  child: Text(
                    'Are you sure you want to end the interview?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 163,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            AppRoutes.home,
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE05359),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        child: const Text(
                          'End Now',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 163,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          // Resume timer if was recording
                          if (_isRecording) _startTimer();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          elevation: 0,
                          side: const BorderSide(
                            color: Color(0xFF1E83FF),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        child: const Text(
                          'Resume',
                          style: TextStyle(
                            color: Color(0xFF1E83FF),
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
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) return const SizedBox();

    final totalQuestions = widget.questions.length;
    final progress = _currentQuestion / totalQuestions;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: _buildTopBar(progress, totalQuestions),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      children: [
                        _buildVideoFeed(),
                        const SizedBox(height: 20),
                        _buildQuestionCard(),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: _buildRecordingButton(),
                ),
              ],
            ),
          ),
        ),
        if (_isUploading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    _currentQuestion >= totalQuestions
                        ? 'Analyzing your interview...'
                        : 'Saving response...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Top bar with progress ──────────────────────────────────────────
  Widget _buildTopBar(double progress, int totalQuestions) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Text(
                'Interview in process',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E83FF),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E83FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_currentQuestion/$totalQuestions',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1E83FF)),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  // ── Live camera feed ───────────────────────────────────────────────
  Widget _buildVideoFeed() {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Live camera or placeholder
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: _isCameraReady && _cameraController != null
                ? SizedBox(
                    width: double.infinity,
                    height: 400,
                    child: CameraPreview(_cameraController!),
                  )
                : Container(
                    width: double.infinity,
                    height: 400,
                    color: Colors.grey[300],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.videocam,
                              size: 64, color: Colors.grey[600]),
                          const SizedBox(height: 16),
                          Text(
                            'Initializing camera...',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          // Overlay: pause + end buttons
          Positioned(
            top: 16,
            right: 16,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF90CAF9),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon:
                        const Icon(Icons.pause, color: Colors.white, size: 20),
                    onPressed: () {
                      if (_isRecording) _toggleRecording();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE05359),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.call_end,
                        color: Colors.white, size: 20),
                    onPressed: _showExitConfirmation,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Question card with per-question timer ──────────────────────────
  Widget _buildQuestionCard() {
    // Timer color: red when < 10 seconds
    final timerColor =
        _timerSeconds < 10 ? const Color(0xFFE05359) : const Color(0xFF1E83FF);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Question $_currentQuestion',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E83FF),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  (widget.questions[_currentQuestion - 1]['type'] ?? 'General')
                          .toString()
                          .toUpperCase()
                          .substring(0, 1) +
                      (widget.questions[_currentQuestion - 1]['type'] ??
                              'General')
                          .toString()
                          .substring(1)
                          .toLowerCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E83FF),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: timerColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatTime(_timerSeconds),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.questions[_currentQuestion - 1]['question'] ??
                'No question text provided.',
            style: const TextStyle(
                fontSize: 15, color: Colors.black87, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── Recording button ───────────────────────────────────────────────
  Widget _buildRecordingButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: _isRecording ? const Color(0xFFE05359) : const Color(0xFF1E83FF),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: (_isRecording
                    ? const Color(0xFFE05359)
                    : const Color(0xFF1E83FF))
                .withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _toggleRecording,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isRecording ? Icons.stop : Icons.mic,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              _isRecording ? 'Stop Recording' : 'Start Recording',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
