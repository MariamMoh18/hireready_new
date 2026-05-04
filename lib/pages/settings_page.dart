import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ai_interview/config/app_routes.dart';
import 'package:ai_interview/config/app_icons.dart';
import 'package:ai_interview/styles/app_text.dart';
import 'package:ai_interview/services/auth_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildCircularButton(
                            context,
                            iconPath: AppIcons.icArrow,
                            onTap: () => Navigator.pop(context),
                          ),
                          _buildCircularButton(
                            context,
                            iconData: Icons.settings_outlined,
                            iconSize: 18,
                            onTap: () {
                              // Settings action
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 35),
                      // Title
                      Text(
                        'Settings',
                        style: Theme.of(context)
                            .extension<AppTextTheme>()
                            ?.boldLg
                            .copyWith(
                              color: const Color(0xFF4B5563),
                            ),
                      ),
                      const SizedBox(height: 16),
                      // Settings List
                      _buildSettingsItem(
                        context,
                        iconPath: AppIcons.icPerson,
                        title: 'Edit profile',
                        onTap: () {
                          Navigator.pushNamed(context, AppRoutes.profile);
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildSettingsItem(
                        context,
                        iconPath: AppIcons.icBell,
                        title: 'Notifications',
                        onTap: () {},
                      ),
                      const SizedBox(height: 16),
                      _buildSettingsItem(
                        context,
                        iconPath: AppIcons.icSheild,
                        title: 'Privacy Policy',
                        onTap: () {},
                      ),
                      const SizedBox(height: 16),
                      _buildSettingsItem(
                        context,
                        iconPath: AppIcons.icGloble,
                        title: 'Language',
                        onTap: () {},
                      ),
                      const SizedBox(height: 16),
                      _buildSettingsItem(
                        context,
                        iconPath: AppIcons.icLogout,
                        title: 'Log out',
                        isError: true,
                        onTap: () async {
                          await AuthService.logout();
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRoutes.login,
                            (route) => false,
                            arguments: {'showLogoutDialog': true},
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularButton(
    BuildContext context, {
    String? iconPath,
    IconData? iconData,
    required VoidCallback onTap,
    double iconSize = 20,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        width: 40,
        height: 40,
        decoration: const ShapeDecoration(
          color: Colors.white,
          shape: CircleBorder(),
        ),
        child: Center(
          child: iconPath != null
              ? SvgPicture.asset(
                  iconPath,
                  width: iconSize,
                  height: iconSize,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF4B5563),
                    BlendMode.srcIn,
                  ),
                )
              : Icon(
                  iconData,
                  size: iconSize,
                  color: const Color(0xFF4B5563),
                ),
        ),
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required String iconPath,
    required String title,
    required VoidCallback onTap,
    bool isError = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadows: const [
            BoxShadow(
              color: Color(0x14789FCE),
              blurRadius: 21.7,
              offset: Offset(0, 10),
              spreadRadius: 0,
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isError
                        ? const Color(0xFFFCE4E5)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      iconPath,
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        isError
                            ? const Color(0xFFE05359)
                            : const Color(0xFF18181B),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: Theme.of(context)
                      .extension<AppTextTheme>()
                      ?.mediumSm
                      .copyWith(
                        color: isError ? const Color(0xFFE05359) : Colors.black,
                      ),
                ),
              ],
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color:
                  isError ? const Color(0xFFE05359) : const Color(0xFF4B5563),
            ),
          ],
        ),
      ),
    );
  }
}
