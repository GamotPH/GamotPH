import 'package:client/screens/home/emergency_response_page.dart';
import 'package:client/screens/home/health_community_page.dart';
import 'package:client/screens/home/hotlines_page.dart';
import 'package:client/screens/home/statistics_page.dart';
import 'package:client/screens/notifications/notifications_page.dart';
import 'package:client/screens/reports/reports_dashboard_page.dart';
import 'package:client/screens/trends/trends_map_page.dart';
import 'package:flutter/material.dart';
import '../screens/home/report_form_screen.dart';
import '../screens/home/scan_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth/login_screen.dart';
import '../screens/history/history_page.dart';
import '../screens/profile/profile_page.dart';

enum NavItem {
  home,
  report,
  scan,
  stats,
  history,
  notifications,
  profile,
  healthCommunity,
  emergency,
  hotlines,
  trends,
}

class HomeLayout extends StatefulWidget {
  final NavItem initialTab;
  const HomeLayout({super.key, this.initialTab = NavItem.home});

  @override
  State<HomeLayout> createState() => HomeLayoutState();
}

class HomeLayoutState extends State<HomeLayout> {
  late NavItem selected;

  @override
  void initState() {
    super.initState();
    selected = widget.initialTab;
  }

  void selectNav(NavItem item) {
    setState(() {
      selected = item;
    });
  }

  String getPageTitle(NavItem item) {
    switch (item) {
      case NavItem.home:
        return 'Reports';
      case NavItem.report:
        return 'Report a Medicine';
      case NavItem.scan:
        return 'Scan Medicine';
      case NavItem.stats:
        return 'Statistics';
      case NavItem.history:
        return 'History';
      case NavItem.notifications:
        return 'Notifications';
      case NavItem.profile:
        return 'Profile';
      case NavItem.healthCommunity:
        return 'Health Community';
      case NavItem.emergency:
        return 'Emergency Response';
      case NavItem.hotlines:
        return 'Health Holines';
      case NavItem.trends:
        return 'Trends';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Supabase.instance.client.auth.currentSession == null) {
      Future.microtask(() {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        }
      });
      return const SizedBox.shrink();
    }

    Widget body;

    switch (selected) {
      case NavItem.home:
        body = const ReportsDashboardPage();
        break;
      case NavItem.report:
        body = const ReportFormScreen();
        break;
      case NavItem.scan:
        body = const ScanPage();
        break;
      case NavItem.history:
        if (Supabase.instance.client.auth.currentUser == null) {
          body = const Center(
            child: Text("🔒 Please log in to view this section."),
          );
        } else {
          body = const HistoryScreen(); // ✅ Use the real screen now
        }
        break;
      case NavItem.stats:
        body = const StatisticsPage();
        break;
      case NavItem.notifications:
        if (Supabase.instance.client.auth.currentUser == null) {
          body = const Center(
            child: Text("🔒 Please log in to view this section."),
          );
        } else {
          body = const NotificationsPage(); // ✅ Use the real screen now
        }
        break;
      case NavItem.profile:
        if (Supabase.instance.client.auth.currentUser == null) {
          body = const Center(
            child: Text("🔒 Please log in to view this section."),
          );
        } else {
          body = const ProfileScreen(); // Replace with real screen
        }
        break;
      case NavItem.healthCommunity:
        body = const HealthCommunityScreen();
        break;
      case NavItem.emergency:
        body = const EmergencyResponseScreen();
        break;
      case NavItem.hotlines:
        body = const HotlinesScreen();
        break;
      case NavItem.trends:
        body = const TrendsMapPage();
        break;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        return Scaffold(
          appBar:
              isDesktop
                  ? null
                  : AppBar(
                    title: Text(getPageTitle(selected)),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 0.5,
                  ),
          drawer: isDesktop ? null : _buildDrawer(),
          body: Row(
            children: [
              if (isDesktop) _buildSidebar(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Page Title
                    if (isDesktop)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        child: Text(
                          getPageTitle(selected),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),

                    const Divider(height: 1),
                    Expanded(child: body),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Drawer _buildDrawer() {
    final user = Supabase.instance.client.auth.currentUser;
    final isLoggedIn = user != null;
    final fullName = user?.userMetadata?['full_name'] ?? user?.email ?? '';
    final email = user?.email ?? '';
    final avatarUrl = user?.userMetadata?['avatar_url'];

    return Drawer(
      child: Column(
        children: [
          // Header
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.deepPurple.shade50),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                "GAMOTPH",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade700,
                ),
              ),
            ),
          ),

          // Navigation
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _navTileWithIcon(Icons.show_chart, "Reports", NavItem.home),
                _navTileWithIcon(Icons.history, "History", NavItem.history),
                _navTileWithIcon(
                  Icons.notifications,
                  "Notifications",
                  NavItem.notifications,
                ),
                _navTileWithIcon(Icons.person, "Profile", NavItem.profile),
              ],
            ),
          ),

          const Divider(),

          // Bottom User Info & Auth
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child:
                isLoggedIn
                    ? Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage:
                                  avatarUrl != null
                                      ? NetworkImage(avatarUrl)
                                      : null,
                              child:
                                  avatarUrl == null
                                      ? const Icon(Icons.person, size: 20)
                                      : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    email,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: () async {
                              await Supabase.instance.client.auth.signOut();
                              if (!mounted) return;
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/',
                                (route) => false,
                              );
                            },
                            icon: const Icon(Icons.logout, size: 18),
                            label: const Text("Logout"),
                          ),
                        ),
                      ],
                    )
                    : SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).maybePop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.login, size: 18),
                        label: const Text("Login"),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final user = Supabase.instance.client.auth.currentUser;
    final isLoggedIn = user != null;
    final fullName = user?.userMetadata?['full_name'] ?? user?.email ?? '';
    final email = user?.email ?? '';
    final avatarUrl = user?.userMetadata?['avatar_url'];

    return Container(
      width: 240,
      color: const Color(0xFFF5F6FA), // light neutral background
      child: Column(
        children: [
          // Sidebar brand/logo
          Container(
            padding: const EdgeInsets.only(
              top: 16,
              bottom: 24,
            ), // reduced padding
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 160, // ensure a good width for scale
                  child: Image.asset(
                    'assets/GAMOTPH-LOGO.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),

          // Navigation
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _navTileWithIcon(Icons.show_chart, "Reports", NavItem.home),
                _navTileWithIcon(Icons.history, "Maps", NavItem.trends),
                _navTileWithIcon(
                  Icons.notifications,
                  "Notifications",
                  NavItem.notifications,
                ),
                _navTileWithIcon(Icons.person, "Profile", NavItem.profile),
              ],
            ),
          ),

          const Divider(),

          // Bottom Section: User Info + Auth Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child:
                isLoggedIn
                    ? Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage:
                                  avatarUrl != null
                                      ? NetworkImage(avatarUrl)
                                      : null,
                              child:
                                  avatarUrl == null
                                      ? const Icon(Icons.person, size: 20)
                                      : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    email,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: () async {
                              await Supabase.instance.client.auth.signOut();
                              if (!mounted) return;
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/',
                                (route) => false,
                              );
                            },
                            icon: const Icon(Icons.logout, size: 18),
                            label: const Text("Logout"),
                          ),
                        ),
                      ],
                    )
                    : SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.login, size: 18),
                        label: const Text("Login"),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  // ListTile _navTile(String title, NavItem item) => ListTile(
  //   title: Text(title),
  //   selected: selected == item,
  //   onTap: () {
  //     setState(() => selected = item);
  //     Navigator.of(context).maybePop(); // Close drawer
  //   },
  // );
  Widget _navTileWithIcon(IconData icon, String title, NavItem item) {
    final isSelected = selected == item;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.deepPurple : Colors.black54,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.deepPurple : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedTileColor: Colors.deepPurple.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () {
          setState(() => selected = item);
        },
      ),
    );
  }
}
