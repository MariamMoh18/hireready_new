import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ai_interview/config/app_icons.dart';
import 'package:ai_interview/config/app_routes.dart';

class CustomBottomNav extends StatelessWidget {
  final String activeRoute;

  const CustomBottomNav({
    super.key,
    required this.activeRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavItem(
            context,
            iconPath: AppIcons.icHome,
            label: 'Home',
            route: AppRoutes.home,
          ),
          _buildNavItem(
            context,
            iconPath: AppIcons.icProgress,
            label: 'Progress',
            route: AppRoutes.progress,
          ),
          _buildNavItem(
            context,
            iconPath: AppIcons.icHistory,
            label: 'History',
            route: AppRoutes.history,
          ),
          _buildNavItem(
            context,
            iconPath: AppIcons.icUser,
            label: 'Profile',
            route: AppRoutes.profile,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required String iconPath,
    required String label,
    required String route,
  }) {
    final bool isActive = activeRoute == route;
    final color = isActive ? const Color(0xFF1E83FF) : Colors.grey;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isActive
            ? null
            : () {
                if (route == AppRoutes.home) {
                  Navigator.pushReplacementNamed(context, route);
                } else {
                  Navigator.pushNamed(context, route);
                }
              },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              iconPath,
              height: 22,
              width: 22,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
