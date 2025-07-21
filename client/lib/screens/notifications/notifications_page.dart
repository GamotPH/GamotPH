import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  // Sample mock notifications (you can later fetch from Supabase)
  final List<Map<String, String>> mockNotifications = const [
    {
      'title': 'New Medicine Alert',
      'body': 'A newly reported side effect for Paracetamol is now listed.',
    },
    {
      'title': 'Case Review',
      'body': 'Your ADR report #124 has been reviewed by an expert.',
    },
    {
      'title': 'Community Update',
      'body': 'A new discussion was posted in the Health Community.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Notifications",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(height: 24),

              // List of notifications
              ...mockNotifications.map((notification) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    leading: const Icon(Icons.notifications),
                    title: Text(notification['title']!),
                    subtitle: Text(notification['body']!),
                  ),
                );
              }).toList(),

              // Fallback when list is empty
              if (mockNotifications.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Text(
                      "🔕 No notifications yet.",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
