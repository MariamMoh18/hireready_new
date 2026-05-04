import 'package:flutter/material.dart';
import 'package:ai_interview/pages/camera/camera_access_page.dart';

class InterviewDurationPage extends StatefulWidget {
  const InterviewDurationPage({super.key});

  @override
  State<InterviewDurationPage> createState() => _InterviewDurationPageState();
}

class _InterviewDurationPageState extends State<InterviewDurationPage> {
  double _sliderValue = 10.0;
  String? _selectedSession;

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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildSlider(),
                    const SizedBox(height: 24),
                    _buildTitleSection(),
                    const SizedBox(height: 32),
                    _buildSessionCard(
                      title: 'Quick',
                      questions: '3-5 Questions',
                      description: 'Perfect for a quick warmup',
                      duration: '10 min',
                      value: 'quick',
                    ),
                    const SizedBox(height: 16),
                    _buildSessionCard(
                      title: 'Standard',
                      questions: '6-10 Questions',
                      description: 'Recommended practice session',
                      duration: '15 min',
                      value: 'standard',
                    ),
                    const SizedBox(height: 16),
                    _buildSessionCard(
                      title: 'Full',
                      questions: '11-15 Questions',
                      description: 'Comprehensive interview simulation',
                      duration: '30 min',
                      value: 'full',
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: _buildNextButton(context),
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
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: Colors.black54,
            ),
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

  Widget _buildSlider() {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: const Color(0xFF1E83FF),
        inactiveTrackColor: const Color(0xFFE3F2FD),
        thumbColor: const Color(0xFF1E83FF),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        trackHeight: 4,
      ),
      child: Slider(
        value: _sliderValue,
        min: 10,
        max: 30,
        divisions: 2,
        onChanged: (value) {
          setState(() {
            _sliderValue = value;
            // Update selected session based on slider value
            if (value <= 10) {
              _selectedSession = 'quick';
            } else if (value <= 15) {
              _selectedSession = 'standard';
            } else {
              _selectedSession = 'full';
            }
          });
        },
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Session Length',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select how long you\'d like to practice',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSessionCard({
    required String title,
    required String questions,
    required String description,
    required String duration,
    required String value,
  }) {
    final isSelected = _selectedSession == value;
    return InkWell(
      onTap: () {
        setState(() {
          if (_selectedSession == value) {
            _selectedSession = null;
          } else {
            _selectedSession = value;
            // Update slider based on selection
            if (value == 'quick') {
              _sliderValue = 10;
            } else if (value == 'standard') {
              _sliderValue = 15;
            } else {
              _sliderValue = 30;
            }
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? null : Colors.white,
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF83C8FF), Color(0xFF1E83FF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color:
                          isSelected ? Colors.white : const Color(0xFF90CAF9),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    questions,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected
                          ? Colors.white.withOpacity(0.9)
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color:
                    isSelected ? Colors.white.withOpacity(0.2) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.white : const Color(0xFF90CAF9),
                  width: 1.5,
                ),
              ),
              child: Text(
                duration,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF90CAF9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextButton(BuildContext context) {
    final isEnabled = _selectedSession != null;
    final buttonColor = isEnabled ? const Color(0xFF1E83FF) : Colors.grey[600]!;

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
        color: isEnabled ? null : buttonColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: ElevatedButton(
        onPressed: isEnabled
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CameraAccessPage(
                      sessionLength: _selectedSession!,
                    ),
                  ),
                );
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Text(
          'Next',
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
