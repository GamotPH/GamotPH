import 'package:flutter/material.dart';
import '../../layout/home_layout.dart';

class HealthCommunityScreen extends StatelessWidget {
  const HealthCommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final layoutState = context.findAncestorStateOfType<HomeLayoutState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextButton.icon(
            onPressed: () {
              layoutState?.selectNav(NavItem.home); // 👈 Return to tile view
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
            style: TextButton.styleFrom(foregroundColor: Colors.deepPurple),
          ),
        ),
        const Expanded(
          child: Center(
            child: Text(
              "👥 Health Community feature coming soon...",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }
}
