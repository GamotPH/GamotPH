import 'package:client/layout/home_layout.dart';
import 'package:flutter/material.dart';
// import 'report_form_screen.dart';
// import 'scan_page.dart';
// import 'statistics_page.dart';
// import 'health_community_page.dart';
// import 'emergency_response_page.dart';
// import 'hotlines_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final homeLayoutState = context.findAncestorStateOfType<HomeLayoutState>();

    return GridView.count(
      crossAxisCount: 3,
      childAspectRatio: 1.2,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _HomeTile(
          title: "Report a Medicine",
          icon: Icons.assignment,
          navItem: NavItem.report,
          onTap: homeLayoutState?.selectNav ?? (_) {},
        ),
        _HomeTile(
          title: "Scan Medicine",
          icon: Icons.qr_code_scanner,
          navItem: NavItem.scan,
          onTap: homeLayoutState?.selectNav ?? (_) {},
        ),
        _HomeTile(
          title: "Statistics",
          icon: Icons.analytics,
          navItem: NavItem.stats,
          onTap: homeLayoutState?.selectNav ?? (_) {},
        ),
        _HomeTile(
          title: "Health Community",
          icon: Icons.group,
          navItem: NavItem.healthCommunity,
          onTap: homeLayoutState?.selectNav ?? (_) {},
        ),
        _HomeTile(
          title: "Emergency Response",
          icon: Icons.warning,
          navItem: NavItem.emergency,
          onTap: homeLayoutState?.selectNav ?? (_) {},
        ),
        _HomeTile(
          title: "Health Hotlines",
          icon: Icons.phone,
          navItem: NavItem.hotlines,
          onTap: homeLayoutState?.selectNav ?? (_) {},
        ),
      ],
    );
  }
}

class _HomeTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final NavItem navItem;
  final void Function(NavItem) onTap;

  const _HomeTile({
    required this.title,
    required this.icon,
    required this.navItem,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(navItem),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.deepPurple.shade50,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
