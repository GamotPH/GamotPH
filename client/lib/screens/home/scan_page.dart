import 'package:flutter/material.dart';
import '../../layout/home_layout.dart';

class ScanPage extends StatelessWidget {
  const ScanPage({super.key});

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
              layoutState?.selectNav(
                NavItem.home,
              ); // Navigate back to tile view
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
            style: TextButton.styleFrom(foregroundColor: Colors.deepPurple),
          ),
        ),
        const Expanded(
          child: Center(
            child: Text(
              "🧪 Scan Page (Coming Soon)",
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }
}
