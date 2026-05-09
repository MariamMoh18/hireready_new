import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ai_interview/config/app_icons.dart';
import 'package:ai_interview/pages/interview_duration_page.dart';
import 'package:ai_interview/pages/profile_page.dart';
import 'package:ai_interview/config/app_routes.dart';
import 'package:ai_interview/widgets/custom_bottom_nav.dart';
import 'package:ai_interview/services/auth_service.dart';
import 'package:ai_interview/services/user_service.dart';
import 'package:ai_interview/services/interview_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userName = '';
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _progress;

  String _industryFromProfile() {
    final direct = _profile?['job_field']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final resume = _profile?['resume'] as String?;
    if (resume == null || resume.trim().isEmpty) return 'Not Set';
    final parts =
        resume.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.first : 'Not Set';
  }

  String _targetRoleFromProfile() {
    final direct = _profile?['target_role']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final resume = _profile?['resume'] as String?;
    if (resume == null || resume.trim().isEmpty) return 'Not Set';
    final parts =
        resume.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return parts.length > 1 ? parts[1] : 'Not Set';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final name = await AuthService.getUserName();
    final profile = await UserService.getProfile();
    final metricsResult = await InterviewService.getDashboardMetrics();

    if (mounted) {
      setState(() {
        _userName = name;
        _profile = profile;
        if (metricsResult['success'] == true) {
          _progress = metricsResult['data'];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Stack(
          children: [
            // Scrollable Content
            Positioned.fill(
              bottom: 90, // Leave space for bottom nav
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 24,
                  children: [
                    _buildHeader(context),
                    _buildReadyCard(context),
                    _buildStatsRow(context),
                  ],
                ),
              ),
            ),
            // Bottom Navigation
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: CustomBottomNav(activeRoute: AppRoutes.home),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            spacing: 12,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: ShapeDecoration(
                  color: const Color(0xFFD9D9D9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 28,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Welcome back',
                          style: TextStyle(
                            color: const Color.fromARGB(255, 54, 54, 55),
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            height: 1.58,
                          ),
                        ),
                        TextSpan(
                          text: ' 👋',
                          style: TextStyle(
                            color: const Color(0xFF9CA3AF),
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            height: 1.58,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _userName,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      height: 1.20,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          const Spacer(),
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
      ),
    );
  }

  Widget _buildReadyCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: ShapeDecoration(
        color: Colors.white /* surface-Secondary */,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        shadows: [
          BoxShadow(
            color: Color(0x14789FCE),
            blurRadius: 21.70,
            offset: Offset(0, 10),
            spreadRadius: 0,
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 20,
        children: [
          SizedBox(
            width: 117,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 10,
              children: [
                SizedBox(
                  width: 117,
                  child: Text(
                    'Ready to practice?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF374151) /* text-heading */,
                      fontSize: 20,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      height: 1.20,
                    ),
                  ),
                ),
                SizedBox(
                  width: 117,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const InterviewDurationPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF1E83FF) /* surface-action */,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      spacing: 4,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: SvgPicture.asset(
                            AppIcons.icPlay,
                            width: 16,
                            height: 16,
                            colorFilter: const ColorFilter.mode(
                                Colors.white, BlendMode.srcIn),
                          ),
                        ),
                        const Text(
                          'Start',
                          style: TextStyle(
                            color: Colors.white /* text-on-action */,
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 89,
            height: 138,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(AppIcons.icMic2),
                fit: BoxFit.fill,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    // Dynamic data from backend
    final targetRole = _targetRoleFromProfile();
    final experienceLevel = _profile?['experience_level'] ?? 'Not Set';
    final industry = _industryFromProfile();
    final avgScore = _progress?['average_score'];
    final totalSessions = _progress?['total_sessions'] ?? 0;

    // We can show the weakest category as the 'trend' for now
    final weakestCategory = _progress?['weakest_category'] ?? '';

    // Format score display
    final scoreDisplay = avgScore != null ? '$avgScore' : '--';
    final trendDisplay = weakestCategory.isNotEmpty
        ? 'Focus: $weakestCategory'
        : 'Start practising!';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        Expanded(
          child: Container(
            height: 372,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              shadows: const [
                BoxShadow(
                  color: Color(0x14789FCE),
                  blurRadius: 21.70,
                  offset: Offset(0, 10),
                  spreadRadius: 0,
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 12,
              children: [
                InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ProfilePage()),
                    );
                    _loadData();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Profile',
                        style: TextStyle(
                          color: Color(0xFF374151),
                          fontSize: 16,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          height: 1.13,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: ShapeDecoration(
                          color: const Color(0xFF1E83FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          shadows: const [
                            BoxShadow(
                              color: Color(0x14789FCE),
                              blurRadius: 21.70,
                              offset: Offset(0, 10),
                            )
                          ],
                        ),
                        child: SvgPicture.asset(
                          AppIcons.icEdit,
                          color: Colors.white,
                          width: 16,
                          height: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 20,
                    children: [
                      _buildProfileStat(AppIcons.icWork, 'Industry:', industry),
                      _buildProfileStat(
                          AppIcons.icPosition, 'Target Position:', targetRole),
                      _buildProfileStat(
                          AppIcons.icProgress, 'Experience:', experienceLevel),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Column(
            spacing: 16,
            children: [
              Container(
                width: double.infinity,
                height: 234,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: ShapeDecoration(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  shadows: const [
                    BoxShadow(
                      color: Color(0x14789FCE),
                      blurRadius: 21.70,
                      offset: Offset(0, 10),
                      spreadRadius: 0,
                    )
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 16,
                  children: [
                    SizedBox(
                      width: 107,
                      child: Text(
                        totalSessions > 0
                            ? 'Average Score'
                            : 'Last Session Score',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF374151),
                          fontSize: 16,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          height: 1.13,
                        ),
                      ),
                    ),
                    Container(
                      width: 94,
                      height: 94,
                      decoration: ShapeDecoration(
                        gradient: SweepGradient(
                          center: Alignment.center,
                          startAngle: 0.0,
                          endAngle: 6.28,
                          colors: [
                            const Color(0xFFE5F1FF), // Lighter track
                            const Color(0xFF1E83FF), // Blue progress
                          ],
                          stops: [
                            avgScore != null ? (1.0 - avgScore / 100.0) : 0.76,
                            avgScore != null ? (1.0 - avgScore / 100.0) : 0.76,
                          ],
                          transform: const GradientRotation(-1.5708),
                        ),
                        shape: const OvalBorder(),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Container(
                          decoration: const ShapeDecoration(
                            color: Colors.white,
                            shape: OvalBorder(),
                          ),
                          child: Center(
                            child: Text(
                              scoreDisplay,
                              style: const TextStyle(
                                color: Color(0xFF48AAFF),
                                fontSize: 40,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                height: 1.20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 85,
                      child: Text(
                        trendDisplay,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF374151),
                          fontSize: 10,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          height: 1.20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: ShapeDecoration(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  shadows: const [
                    BoxShadow(
                      color: Color(0x14789FCE),
                      blurRadius: 21.70,
                      offset: Offset(0, 10),
                      spreadRadius: 0,
                    )
                  ],
                ),
                child: Column(
                  spacing: 16,
                  children: [
                    const SizedBox(
                      width: 127,
                      child: Text(
                        'Recommended Practice',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF374151),
                          fontSize: 16,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          height: 1.13,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: ShapeDecoration(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(
                            width: 1,
                            color: Color(0xFF0661FF),
                          ),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        shadows: const [
                          BoxShadow(
                            color: Color(0x0C101828),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                            spreadRadius: 0,
                          )
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Confidence',
                          style: TextStyle(
                            color: Color(0xFF0661FF),
                            fontSize: 14,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileStat(String icon, String label, String value) {
    return SizedBox(
      width: 90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 4,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: ShapeDecoration(
              color: const Color(0xFFD6EAFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              shadows: const [
                BoxShadow(
                  color: Color(0x14789FCE),
                  blurRadius: 21.70,
                  offset: Offset(0, 10),
                  spreadRadius: 0,
                )
              ],
            ),
            child: SvgPicture.asset(
              icon,
              width: 16,
              height: 16,
              color: const Color(0xFF1E83FF),
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1E83FF),
              fontSize: 12,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF4B5563),
              fontSize: 12,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
