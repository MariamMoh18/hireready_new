import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ai_interview/pages/camera/interview_preparation_page.dart';

class CameraAccessPage extends StatefulWidget {
  final String sessionLength;

  const CameraAccessPage({super.key, required this.sessionLength});

  @override
  State<CameraAccessPage> createState() => _CameraAccessPageState();
}

class _CameraAccessPageState extends State<CameraAccessPage> {
  CameraController? _cameraController;
  bool _cameraAccessGranted = false;
  bool _micAccessGranted = false;
  String _micStatus = 'Checking...';
  bool _isCameraInitialized = false;
  bool _isCameraStopped = false;
  List<CameraDescription>? _cameras;
  final bool _isStartingSession = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras ??= await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        // Use front camera if available, otherwise use the first camera
        final camera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras!.first,
        );

        _cameraController = CameraController(
          camera,
          ResolutionPreset.medium,
          enableAudio: false, // We'll handle audio separately
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
            _isCameraStopped = false;
            _cameraAccessGranted = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _isCameraStopped = true;
        });
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (!_cameraAccessGranted || _cameras == null || _cameras!.isEmpty) {
      return;
    }

    if (_isCameraStopped) {
      // Start camera
      await _initializeCamera();
    } else {
      // Stop camera
      if (_cameraController != null) {
        await _cameraController!.dispose();
        _cameraController = null;
      }
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _isCameraStopped = true;
        });
      }
    }
  }

  Future<void> _checkPermissions() async {
    if (kIsWeb) {
      // On web, permission_handler doesn't work.
      // Directly initialize camera — the browser will show its own
      // "Allow camera?" dialog when the camera plugin calls getUserMedia.
      await _initializeCamera();
      if (mounted) {
        setState(() {
          _micAccessGranted = _isCameraInitialized;
          _micStatus = _isCameraInitialized ? 'Granted' : 'Denied';
        });
      }
      // If first attempt failed (user might have been slow to click Allow),
      // retry once after a short delay
      if (!_isCameraInitialized) {
        await Future.delayed(const Duration(seconds: 2));
        await _initializeCamera();
        if (mounted) {
          setState(() {
            _micAccessGranted = _isCameraInitialized;
            _micStatus = _isCameraInitialized ? 'Granted' : 'Denied';
          });
        }
      }
      return;
    }

    // Native (Android/iOS) — use permission_handler
    final cameraStatus = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _cameraAccessGranted = cameraStatus.isGranted;
      });
    }
    if (cameraStatus.isGranted) {
      await _initializeCamera();
    }
    final micStatus = await Permission.microphone.request();
    if (mounted) {
      setState(() {
        _micAccessGranted = micStatus.isGranted;
        _micStatus = micStatus.isGranted ? 'Granted' : 'Denied';
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: _buildAppBar(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildProgressBar(),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitleSection(),
                    const SizedBox(height: 24),
                    _buildVideoPreview(),
                    const SizedBox(height: 32),
                    _buildMicrophoneTest(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: _buildContinueButton(context),
            ),
          ],
        ),
      ),
    );
  }

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
            onPressed: () {
              Navigator.pop(context);
            },
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
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 4,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
        child: Stack(
          children: [
            Container(width: double.infinity, color: Colors.grey[200]),
            FractionallySizedBox(
              widthFactor: 0.67, // About 2/3 filled
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E83FF), Color(0xFF0066CC)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Before You Start',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Let\'s make sure everything is working properly.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildVideoPreview() {
    final cameraReady = _isCameraInitialized &&
        _cameraController != null &&
        !_isCameraStopped;
    final previewSize =
        cameraReady ? _cameraController!.value.previewSize : null;

    return Center(
      child: Container(
        width: 342,
        height: 456,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(24),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Camera preview or placeholder
              if (cameraReady && previewSize != null)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: previewSize.width,
                    height: previewSize.height,
                    child: CameraPreview(_cameraController!),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.grey[400]!, Colors.grey[300]!],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.videocam_off,
                          size: 64,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _cameraAccessGranted
                              ? 'Initializing camera...'
                              : 'Camera access required',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Camera status badge in top right (clickable)
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: _cameraAccessGranted ? _toggleCamera : null,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cameraReady ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      cameraReady ? Icons.videocam : Icons.videocam_off,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMicrophoneTest() {
    final isGranted = _micAccessGranted;
    final backgroundColor = isGranted
        ? const Color(0xFFE8F5E9) // Light green background
        : const Color(0xFFE3F2FD); // Light blue background
    final iconBackgroundColor = isGranted
        ? const Color(0xFFC8E6C9) // Light green icon background
        : const Color(0xFF90CAF9); // Light blue icon background
    final textColor = isGranted
        ? const Color(0xFF2E7D32) // Dark green text
        : const Color(0xFF1976D2); // Darker blue text
    final iconColor = isGranted
        ? const Color(0xFF2E7D32) // Dark green icon
        : const Color(0xFF1976D2); // Darker blue icon

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Microphone Test',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.mic, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Microphone access',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isGranted ? 'Audio is clear' : _micStatus,
                      style: TextStyle(fontSize: 14, color: textColor),
                    ),
                  ],
                ),
              ),
              if (isGranted)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: textColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToPreparation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InterviewPreparationPage(
          sessionLength: widget.sessionLength,
        ),
      ),
    );
  }

  Widget _buildContinueButton(BuildContext context) {
    // Button is enabled if permissions granted and not currently loading via API
    final isEnabled =
        _cameraAccessGranted && _micAccessGranted && !_isStartingSession;

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: isEnabled
            ? const LinearGradient(
                colors: [Color(0xFF1E83FF), Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isEnabled ? null : Colors.grey[600],
        borderRadius: BorderRadius.circular(30),
      ),
      child: ElevatedButton(
        onPressed: isEnabled ? _navigateToPreparation : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: _isStartingSession
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'Continue',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
