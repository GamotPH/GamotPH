// lib/screens/history/history_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = supabase.Supabase.instance.client.auth.currentUser;
    final String? userId = user?.id;

    // If there is no logged-in user, show a friendly message (or navigate to login)
    if (userId == null) {
      return const Center(child: Text('You are not signed in.'));
    }

    final future = supabase.Supabase.instance.client
        .from('ADR_Reports') // adjust if your table name differs
        .select()
        .eq('userID', userId) // userId is non-null here
        .order('created_at', ascending: false)
        .limit(20)
        .then((res) => List<Map<String, dynamic>>.from(res));

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final reports = snapshot.data ?? [];
        if (reports.isEmpty) {
          return const Center(child: Text('No ADR reports found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Text(report['drugName'] ?? 'Unknown medicine'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Symptoms: ${report['reactionDescription'] ?? 'N/A'}'),
                    Text(
                      'Reported on: ${report['created_at']?.toString().substring(0, 10)}',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
